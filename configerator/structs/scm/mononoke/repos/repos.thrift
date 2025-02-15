// @generated SignedSource<<b2d2c0d4013f8eb421d0be15b74a2a75>>
// DO NOT EDIT THIS FILE MANUALLY!
// This file is a mechanical copy of the version in the configerator repo. To
// modify it, edit the copy in the configerator repo instead and copy it over by
// running the following in your fbcode directory:
//
// configerator-thrift-updater scm/mononoke/repos/repos.thrift

/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

namespace py configerator.mononoke.repos

 // NOTICE:
 // Don't use 'defaults' for any of these values (e.g. 'bool enabled = true')
 // because these structs will be deserialized by serde in rust. The following
 // rules apply upon deserialization:
 //   1) specified default values are ignored, default values will always be
 //      the 'Default::default()' value for a given type. For example, even
 //      if you specify:
 //          1: bool enabled = true,
 //
 //       upon decoding, if the field enabled isn't present, the default value
 //       will be false.
 //
 //   2) not specifying optional won't actually make your field required,
 //      neither will specifying required make any field required. Upon decoding
 //      with serde, all values will be Default::default() and no error will be
 //      given.
 //
 //   3) the only way to detect wether a field was specified in the structure
 //      being deserialized is by making a field optional. This will result in
 //      a 'None' value for a Option<T> in rust. So the way we can give default
 //      values other then 'Default::default()' is by making a field optional,
 //      and then explicitly handle 'None' after deserialization.

struct RawRepoConfigs {
    1: map<string, RawCommitSyncConfig> (rust.type = "HashMap") commit_sync,
    2: RawCommonConfig common,
    3: map<string, RawRepoConfig> (rust.type = "HashMap") repos, # to be renamed to repo_configs
    4: map<string, RawStorageConfig> (rust.type = "HashMap") storage, # to be renamed to storage_configs

    5: RawRepoDefinitions repo_definitions,
} (rust.exhaustive)

struct RawRepoDefinitions {
    // map from repo_name to a simple structure containing repo-specific data like
    // repo_id or repo_name that can be used at runtime whenever RawRepoConfig
    // needs it.
    1: map<string, RawRepoDefinition> (rust.type = "HashMap") repo_definitions,
} (rust.exhaustive)

struct RawRepoDefinition {
    // Most important - the unique ID of this Repo
    // Required - don't let the optional comment fool you, see notice above.
    1: optional i32 repo_id,

    2: optional string repo_name,

    // In case this repo is related with some other repo in other id namespace.
    3: optional i32 external_repo_id,

    // Key into RawRepoConfigs.repos
    4: optional string repo_config,

    // DB we're using for write-locking repos. This is separate from the rest
    // because it's the same one Mercurial uses, to make it easier to manage
    // repo locking for both from one tool.
    5: optional string write_lock_db_address,

    // Name of the ACL used for this repo.
    6: optional string hipster_acl,

    // Repo is enabled for use.
    7: optional bool enabled,

    // Repo is read-only (default false).
    8: optional bool readonly,

    // Should this repo be backed up?
    9: optional bool needs_backup,

    // In case this is a backup repo, what's the origin repo name?
    10: optional string backup_source_repo_name,
} (rust.exhaustive)

struct RawRepoConfig {

    // Persistent storage - contains location of metadata DB and name of
    // blobstore we're using. We reference the common storage config by name.
    // Required - don't let the optional comment fool you, see notice above
    2: optional string storage_config,

    // Local definitions of storage (override the global defined storage)
    3: optional map<string, RawStorageConfig> storage,

    // Define special bookmarks with parameters
    6: optional list<RawBookmarkConfig> bookmarks,
    7: optional i64 bookmarks_cache_ttl,

    // Define hook manager
    8: optional RawHookManagerParams hook_manager_params,

    // Define hook available for use on bookmarks
    9: optional list<RawHookConfig> hooks,

    // This enables or disables verification for censored blobstores
    11: optional bool redaction,

    12: optional i64 generation_cache_size,
    13: optional string scuba_table,
    14: optional string scuba_table_hooks,
    15: optional i64 delay_mean,
    16: optional i64 delay_stddev,
    17: optional RawCacheWarmupConfig cache_warmup,
    18: optional RawPushParams push,
    19: optional RawPushrebaseParams pushrebase,
    20: optional RawLfsParams lfs,
    22: optional i64 hash_validation_percentage,
    23: optional string skiplist_index_blobstore_key,
    24: optional RawBundle2ReplayParams bundle2_replay_params,
    25: optional RawInfinitepushParams infinitepush,
    26: optional i64 list_keys_patterns_max,
    27: optional RawFilestoreParams filestore,
    28: optional i64 hook_max_file_size,
    31: optional RawSourceControlServiceParams source_control_service,
    30: optional RawSourceControlServiceMonitoring
                   source_control_service_monitoring,
    // Types of derived data that are derived for this repo and are safe to use
    33: optional RawDerivedDataConfig derived_data_config,

    // Log Scuba samples to files. Largely only useful in tests.
    34: optional string scuba_local_path,
    35: optional string scuba_local_path_hooks,

    // Name of this repository in hgsql. This is used for syncing mechanisms
    // that interact directly with hgsql data, notably the hgsql repo lock
    36: optional string hgsql_name,

    // Name of this repository in hgsql for globalrevs. Required for syncing
    // globalrevs through the sync job.
    37: optional string hgsql_globalrevs_name,

    38: optional RawSegmentedChangelogConfig segmented_changelog_config,
    39: optional bool enforce_lfs_acl_check,
    // Use warm bookmark cache while serving data hg wireprotocol
    40: optional bool repo_client_use_warm_bookmarks_cache,
    // Deprecated
    41: optional bool warm_bookmark_cache_check_blobimport,
    // A collection of knobs to enable/disable functionality in repo_client module
    42: optional RawRepoClientKnobs repo_client_knobs,
    43: optional string phabricator_callsign,
    // Define parameters for backups jobs
    44: optional RawBackupRepoConfig backup_config
    // Define parameters for repo scrub/walker jobs
    45: optional RawWalkerConfig walker_config
} (rust.exhaustive)

struct RawWalkerConfig {
    // Controls if scrub of data into history is enabled
    1: bool scrub_enabled,
    // Controls if validation of shallow walk from master enabled
    2: bool validate_enabled,
} (rust.exhaustive)

struct RawBackupRepoConfig {
    // Enable backup verification job for this repo
    2: bool verification_enabled,
} (rust.exhaustive)

struct RawRepoClientKnobs {
  1: bool allow_short_getpack_history,
} (rust.exhaustive)

struct RawDerivedDataConfig {
  1: optional string scuba_table,
  // 2: deleted
  // 3: deleted
  // 4: deleted
  5: optional RawDerivedDataTypesConfig enabled, // deprecated
  6: optional RawDerivedDataTypesConfig backfilling, // deprecated
  7: optional map<string, RawDerivedDataTypesConfig> available_configs,
  8: optional string enabled_config_name,
} (rust.exhaustive)

struct RawDerivedDataTypesConfig {
  1: set<string> types,
  6: map<string, string> mapping_key_prefixes,
  2: optional i16 unode_version,
  3: optional i64 blame_filesize_limit,
  4: optional bool hg_set_committer_extra,
  5: optional i16 blame_version,
} (rust.exhaustive)

struct RawBlobstoreDisabled {} (rust.exhaustive)
struct RawBlobstoreFilePath {
    1: string path,
} (rust.exhaustive)
struct RawBlobstoreManifold {
    1: string manifold_bucket,
    2: string manifold_prefix,
} (rust.exhaustive)
struct RawBlobstoreMysql {
    // 1: deleted
    // 2: deleted
    3: RawDbShardableRemote remote,
} (rust.exhaustive)
struct RawBlobstoreMultiplexed {
    // The scuba table to log stats per underlying blobstore
    1: optional string scuba_table,
    2: list<RawBlobstoreIdConfig> components,
    3: optional i64 scuba_sample_rate,
    4: optional i32 multiplex_id,
    5: optional RawDbConfig queue_db,
    // The number of components that must successfully `put` a blob before the
    // multiplex as a whole claims that it successfully `put` the blob
    6: optional i64 minimum_successful_writes,
    // The scuba table to log stats of the multiplexed blobstore operations
    7: optional string multiplex_scuba_table,
    // The number of reads needed to decided a blob is not present
    8: optional i64 not_present_read_quorum,
} (rust.exhaustive)
struct RawBlobstoreManifoldWithTtl {
    1: string manifold_bucket,
    2: string manifold_prefix,
    3: i64 ttl_secs,
} (rust.exhaustive)
struct RawBlobstoreLogging {
    1: optional string scuba_table,
    2: optional i64 scuba_sample_rate,
    3: RawBlobstoreConfig blobstore (rust.box),
} (rust.exhaustive)
struct RawBlobstorePackRawFormat {} (rust.exhaustive)
struct RawBlobstorePackZstdFormat {
    1: i32 compression_level,
} (rust.exhaustive)
union RawBlobstorePackFormat {
    1: RawBlobstorePackRawFormat Raw,
    2: RawBlobstorePackZstdFormat ZstdIndividual,
}
struct RawBlobstorePackConfig {
    1: RawBlobstorePackFormat put_format,
} (rust.exhaustive)
struct RawBlobstorePack {
    1: RawBlobstoreConfig blobstore (rust.box),
    2: optional RawBlobstorePackConfig pack_config,
} (rust.exhaustive)
struct RawBlobstoreS3 {
    1: string bucket,
    2: string keychain_group,
    3: string region_name,
    4: string endpoint,
    // Limit the number of concurrent operations to S3
    // blobstore.
    5: optional i32 num_concurrent_operations,
} (rust.exhaustive)

// Configuration for a single blobstore. These are intended to be defined in a
// separate blobstore.toml config file, and then referenced by name from a
// per-server config. Names are only necessary for blobstores which are going
// to be used by a server. The id field identifies the blobstore as part of a
// multiplex, and need not be defined otherwise. However, once it has been set
// for a blobstore, it must remain unchanged.
union RawBlobstoreConfig {
    1: RawBlobstoreDisabled disabled,
    2: RawBlobstoreFilePath blob_files,
    // 3: deleted
    4: RawBlobstoreFilePath blob_sqlite,
    5: RawBlobstoreManifold manifold,
    6: RawBlobstoreMysql mysql,
    7: RawBlobstoreMultiplexed multiplexed,
    8: RawBlobstoreManifoldWithTtl manifold_with_ttl,
    9: RawBlobstoreLogging logging,
    10: RawBlobstorePack pack,
    11: RawBlobstoreS3 s3,
}

// A write-mostly blobstore is one that is not read from in normal operation.
// Mononoke will read from it in two cases:
// 1. Verifying that data is present in all blobstores (scrub etc)
// 2. Where all "normal" (not write-mostly) blobstores fail to return a blob (error or missing)
union RawMultiplexedStoreType {
    1: RawMultiplexedStoreNormal normal,
    2: RawMultiplexedStoreWriteMostly write_mostly,
}

struct RawMultiplexedStoreNormal {}
struct RawMultiplexedStoreWriteMostly {} (rust.exhaustive)

struct RawBlobstoreIdConfig {
    1: i64 blobstore_id,
    2: RawBlobstoreConfig blobstore,
    3: optional RawMultiplexedStoreType store_type,
} (rust.exhaustive)

struct RawDbLocal {
    1: string local_db_path,
} (rust.exhaustive)

struct RawDbRemote {
    1: string db_address,
    // 2: deleted
} (rust.exhaustive)

struct RawDbShardedRemote {
    1: string shard_map,
    2: i32 shard_num,
} (rust.exhaustive)

union RawDbShardableRemote {
    1: RawDbRemote unsharded,
    2: RawDbShardedRemote sharded,
}

union RawDbConfig {
    1: RawDbLocal local,
    2: RawDbRemote remote,
}

struct RawRemoteMetadataConfig {
    1: RawDbRemote primary,
    2: RawDbShardableRemote filenodes,
    3: RawDbRemote mutation,
} (rust.exhaustive)

union RawMetadataConfig {
    1: RawDbLocal local,
    2: RawRemoteMetadataConfig remote,
}

struct RawEphemeralBlobstoreConfig {
    1: RawBlobstoreConfig blobstore,
    2: RawDbConfig metadata,
    4: i64 initial_bubble_lifespan_secs,
    5: i64 bubble_expiration_grace_secs,
} (rust.exhaustive)

struct RawStorageConfig {
    // 1: deleted
    3: RawMetadataConfig metadata,
    2: RawBlobstoreConfig blobstore,
    4: optional RawEphemeralBlobstoreConfig ephemeral_blobstore,
} (rust.exhaustive)

struct RawPushParams {
    1: optional bool pure_push_allowed,
    2: optional string commit_scribe_category,
} (rust.exhaustive)

struct RawPushrebaseParams {
    1: optional bool rewritedates,
    2: optional i64 recursion_limit,
    3: optional string commit_scribe_category,
    4: optional bool block_merges,
    5: optional bool forbid_p2_root_rebases,
    6: optional bool casefolding_check,
    7: optional bool emit_obsmarkers,
    // This eventually will be removed and superseded by
    // globalrevs_publishing_bookmark.
    8: optional bool assign_globalrevs,
    9: optional bool populate_git_mapping,
    // A bookmark that assigns globalrevs. This bookmark can only be pushed to
    // via pushrebase. Other bookmarks can only be pushed to commits that are
    // ancestors of this bookmark.
    10: optional string globalrevs_publishing_bookmark,
    // For the case when one repo is linked to another (a.k.a. megarepo)
    // there's a special commit extra that allows changing the mapping
    // used to rewrite a commit from one repo to another.
    // Normally pushes of a commit like this are not allowed unless
    // this option is set to false.
    11: optional bool allow_change_xrepo_mapping_extra,
} (rust.exhaustive)

struct RawBookmarkConfig {
    // Either the regex or the name should be provided, not both
    1: optional string regex,
    2: optional string name,
    3: list<RawBookmarkHook> hooks,
    // Are non fastforward moves allowed for this bookmark
    4: bool only_fast_forward,

    // If specified, and if the user's unixname is known, only users who
    // belong to this group or match allowed_users will be allowed to move this
    // bookmark.
    5: optional string allowed_users,

    // If specified, and if the user's unixname is known, only users who
    // belong to this group or match allowed_users will be allowed to move this
    // bookmark.
    9: optional string allowed_hipster_group,

    // Deprecated
    8: optional bool allow_only_external_sync,

    // Whether or not to rewrite dates when processing pushrebase pushes
    6: optional bool rewrite_dates,

    // Other bookmarks whose ancestors are skipped when running hooks
    //
    // This is used during plain bookmark pushes and other simple bookmark
    // updates to avoid running hooks on commits that have already passed the
    // hook.
    //
    // For example, if this field contains "master", and we move a release
    // bookmark like this:
    //
    //   o master
    //   :
    //   : o new
    //   :/
    //   o B
    //   :
    //   : o old
    //   :/
    //   o A
    //   :
    //
    // then changesets in the range A::B will be skipped by virtue of being
    // ancestors of master, which should mean they have already passed the
    // hook.
    7: optional list<string> hooks_skip_ancestors_of,

    // Ensure that given bookmark(s) are ancestors of `ensure_ancestor_of`
    // bookmark. That also implies that it's not longer possible to
    // pushrebase to these bookmarks.
    10: optional string ensure_ancestor_of,

    // This option allows moving a bookmark to a commit that's already
    // public while bypassing all the hooks. Note that should be fine,
    // because commit is already public, meaning that hooks already
    // should have been run when the commit was first made public.
    11: optional bool allow_move_to_public_commits_without_hooks,
} (rust.exhaustive)

struct RawWhitelistEntry {
    1: optional string tier,
    2: optional string identity_data,
    3: optional string identity_type,
} (rust.exhaustive)

struct RawRedactionConfig {
    // Blobstore config for redaction config, indexed by name
    1: string blobstore,
    // Blobstore used to store backup of the redaction config, usually
    // darkstorm. Only used on admin command that creates the config.
    2: optional string darkstorm_blobstore,
    // Configerator path where RedactionSets are
    // TODO: Once the whole config is hot reloadable, move redaction
    // sets inside this struct instead
    3: string redaction_sets_location,
} (rust.exhaustive)

struct RawCommonConfig {
    1: optional list<RawWhitelistEntry> whitelist_entry,
    2: optional string loadlimiter_category,

    // Scuba table for logging redacted file access attempts
    3: optional string scuba_censored_table,
    // Local file to log redacted file accesses to (useful in tests).
    4: optional string scuba_local_path_censored,

    // Whether to enable the control API over HTTP. At this time, this is
    // only meant to be used in tests.
    5: bool enable_http_control_api,

    6: RawRedactionConfig redaction_config,
} (rust.exhaustive)

struct RawCacheWarmupConfig {
    1: string bookmark,
    2: optional i64 commit_limit,
    3: optional bool microwave_preload,
} (rust.exhaustive)

struct RawBookmarkHook {
    1: string hook_name,
} (rust.exhaustive)

struct RawHookManagerParams {
    /// Wether to disable the acl checker or not (intended for testing purposes)
    1: bool disable_acl_checker,
    2: bool all_hooks_bypassed,
    3: optional string bypassed_commits_scuba_table,
} (rust.exhaustive)

struct RawHookConfig {
    1: string name,
    4: optional string bypass_commit_string,
    5: optional string bypass_pushvar,
    6: optional map<string, string> (rust.type = "HashMap") config_strings,
    7: optional map<string, i32> (rust.type = "HashMap") config_ints,
    8: optional map<string, list<string>> (rust.type = "HashMap") config_string_lists,
    9: optional map<string, list<i32>> (rust.type = "HashMap") config_int_lists,
} (rust.exhaustive)

struct RawLfsParams {
    1: optional i64 threshold,
    // What percentage of client host gets lfs pointers
    2: optional i32 rollout_percentage,
    // Whether to generate lfs blobs in hg sync job
    3: optional bool generate_lfs_blob_in_hg_sync_job,
    // 4: deleted
} (rust.exhaustive)

struct RawBundle2ReplayParams {
    1: optional bool preserve_raw_bundle2,
} (rust.exhaustive)

enum RawCommitcloudBookmarksFiller {
    DISABLED = 0,
    BACKFILL = 1,
    FORWARDFILL = 2,
    BIDIRECTIONAL = 3,
}

struct RawInfinitepushParams {
    1: bool allow_writes,
    2: optional string namespace_pattern,
    3: optional bool hydrate_getbundle_response,
    4: optional bool populate_reverse_filler_queue,
    5: optional string commit_scribe_category,
    6: RawCommitcloudBookmarksFiller bookmarks_filler,
    7: optional bool populate_reverse_bookmarks_filler_queue,
} (rust.exhaustive)

struct RawFilestoreParams {
    1: i64 chunk_size,
    2: i32 concurrency,
} (rust.exhaustive)

struct RawCommitSyncSmallRepoConfig {
    1: i32 repoid,
    2: string default_action,
    3: optional string default_prefix,
    4: string bookmark_prefix,
    5: map<string, string> mapping,
    6: string direction,
} (rust.exhaustive)

struct RawCommitSyncConfig {
    1: i32 large_repo_id,
    2: list<string> common_pushrebase_bookmarks,
    3: list<RawCommitSyncSmallRepoConfig> small_repos,
    4: optional string version_name,
} (rust.exhaustive)

struct RawSourceControlServiceParams {
    // Whether ordinary users can write through the source control service.
    1: bool permit_writes,

    // Whether service users can write through the source control service.
    2: bool permit_service_writes,

    // ACL to use for verifying a caller has write access on behalf of a service.
    3: optional string service_write_hipster_acl,

    // Map from service name to the restrictions that apply for that service.
    4: optional map<string, RawServiceWriteRestrictions> service_write_restrictions,

    // Whether users can create commits without parents.
    5: bool permit_commits_without_parents,
} (rust.exhaustive)

struct RawServiceWriteRestrictions {
    // The service is permitted to call these methods.
    1: set<string> permitted_methods,

    // The service is permitted to modify files with these path prefixes.
    2: optional set<string> permitted_path_prefixes,

    // The service is permitted to modify these bookmarks.
    3: optional set<string> permitted_bookmarks,

    // The service is permitted to modify bookmarks that match this regex.
    4: optional string permitted_bookmark_regex,
} (rust.exhaustive)

// Raw configuration for health monitoring of the
// source-control-as-a-service solutions
struct RawSourceControlServiceMonitoring {
    1: list<string> bookmarks_to_report_age,
} (rust.exhaustive)

struct RawSegmentedChangelogConfig {
    // Whether Segmented Changelog should even be initialized.
    1: optional bool enabled,

    // 2: deleted

    // The bookmark that is followed to construct the Master group of the Dag.
    // Defaults to "master".
    3: optional string master_bookmark,

    // How often the tailer should check for updates to the master_bookmark and
    // perform updates. The tailer is disabled when the period is set to 0.
    4: optional i64 tailer_update_period_secs,

    // By default a mononoke process will look for Dags to load from
    // blobstore.  In tests we may not have prebuilt Dags to load so we have
    // this setting to allow us to skip that step and initialize with an empty
    // Dag.
    // We don't want to set this in production.
    5: optional bool skip_dag_load_at_startup,

    // How often an Dag will be reloaded from saves.
    // The Dag will not reload when the period is set to 0.
    6: optional i64 reload_dag_save_period_secs,

    // How often the in process Dag will check the master bookmark to update
    // itself.  The Dag will not check master when the period is set to 0.
    7: optional i64 update_to_master_bookmark_period_secs,

    // List of bonsai changeset to include in the segmented changelog during reseeding.
    //
    // To explain why we might need `bonsai_changesets_to_include` - say we have a
    // commit graph like this:
    // ```
    //  B <- master
    //  |
    //  A
    //  |
    // ...
    // ```
    // Then we move a master bookmark backwards to A and create a new commit on top
    // (this is a very rare situation, but it might happen during sevs)
    //
    // ```
    //  C <- master
    //  |
    //  |  B
    //  | /
    //  A
    //  |
    // ...
    // ```
    //
    // Clients might have already pulled commit B, and so they assume it's present on
    // the server. However if we reseed segmented changelog then commit B won't be
    // a part of a new reseeded changelog because B is not an ancestor of master anymore.
    // It might lead to problems - clients might fail because server doesn't know about
    // a commit they assume it should know of, and server would do expensive sql requests
    // (see S242328).
    //
    // `bonsai_changesets_to_include` might help with that - if we add `B` to
    // `bonsai_changesets_to_include` then every reseeding would add B and it's
    // ancestors to the reseeded segmented changelog.
    8: optional list<string> bonsai_changesets_to_include,
} (rust.exhaustive)
