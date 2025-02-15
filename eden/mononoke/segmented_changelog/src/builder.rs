/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::sync::Arc;

use anyhow::{Context, Result};
use blobstore::Blobstore;
use bookmarks::Bookmarks;
use changeset_fetcher::ArcChangesetFetcher;
use context::CoreContext;
use fbinit::FacebookInit;
use metaconfig_types::SegmentedChangelogConfig;
use repo_identity::RepoIdentity;
use sql_construct::{SqlConstruct, SqlConstructFromMetadataDatabaseConfig};
use sql_ext::replication::NoReplicaLagMonitor;
use sql_ext::SqlConnections;

use crate::iddag::IdDagSaveStore;
use crate::idmap::{CacheHandlers, ConcurrentMemIdMap, IdMapFactory};
use crate::manager::SegmentedChangelogManager;
use crate::on_demand::OnDemandUpdateSegmentedChangelog;
use crate::periodic_reload::PeriodicReloadSegmentedChangelog;
use crate::version_store::SegmentedChangelogVersionStore;
use crate::{
    seedheads_from_config, CloneHints, DisabledSegmentedChangelog, InProcessIdDag,
    SegmentedChangelog,
};

#[derive(Clone)]
pub struct SegmentedChangelogSqlConnections(pub SqlConnections);

impl SqlConstruct for SegmentedChangelogSqlConnections {
    const LABEL: &'static str = "segmented_changelog";

    const CREATION_QUERY: &'static str = include_str!("../schemas/sqlite-segmented-changelog.sql");

    fn from_sql_connections(connections: SqlConnections) -> Self {
        Self(connections)
    }
}

impl SqlConstructFromMetadataDatabaseConfig for SegmentedChangelogSqlConnections {}

pub async fn new_server_segmented_changelog<'a>(
    fb: FacebookInit,
    ctx: &'a CoreContext,
    repo_identity: &'a RepoIdentity,
    config: SegmentedChangelogConfig,
    connections: SegmentedChangelogSqlConnections,
    changeset_fetcher: ArcChangesetFetcher,
    bookmarks: Arc<dyn Bookmarks>,
    blobstore: Arc<dyn Blobstore>,
    cache_pool: Option<cachelib::VolatileLruCachePool>,
) -> Result<Arc<dyn SegmentedChangelog + Send + Sync>> {
    if !config.enabled {
        return Ok(Arc::new(DisabledSegmentedChangelog::new()));
    }
    let repo_id = repo_identity.id();
    let seed_heads =
        seedheads_from_config(ctx, &config).context("finding segmented changelog heads")?;
    if config.skip_dag_load_at_startup {
        // This is a special case. We build Segmented Changelog using an in process iddag and idmap
        // and update then on demand.
        // All other configuration is ignored, for example there won't be periodic updates
        // following a bookmark.
        return Ok(Arc::new(OnDemandUpdateSegmentedChangelog::new(
            ctx.clone(),
            repo_id,
            InProcessIdDag::new_in_process(),
            Arc::new(ConcurrentMemIdMap::new()),
            changeset_fetcher,
            bookmarks,
            seed_heads,
            None,
        )?));
    }
    let replica_lag_monitor = Arc::new(NoReplicaLagMonitor());
    let mut idmap_factory = IdMapFactory::new(connections.0.clone(), replica_lag_monitor, repo_id);
    if let Some(pool) = cache_pool {
        idmap_factory = idmap_factory.with_cache_handlers(CacheHandlers::prod(fb, pool));
    }
    let sc_version_store = SegmentedChangelogVersionStore::new(connections.0.clone(), repo_id);
    let iddag_save_store = IdDagSaveStore::new(repo_id, blobstore.clone());
    let clone_hints = CloneHints::new(connections.0, repo_id, blobstore);
    let manager = SegmentedChangelogManager::new(
        repo_id,
        sc_version_store,
        iddag_save_store,
        idmap_factory,
        changeset_fetcher,
        bookmarks,
        seed_heads,
        config.update_to_master_bookmark_period,
        Some(clone_hints),
    );
    let name = repo_identity.name().to_string();
    let sc = match config.reload_dag_save_period {
        None => manager.load(ctx).await?,
        Some(reload_period) => Arc::new(
            PeriodicReloadSegmentedChangelog::start_from_manager(ctx, reload_period, manager, name)
                .await?,
        ),
    };
    Ok(sc)
}
