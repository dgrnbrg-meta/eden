/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

pub use super::define_flags;
pub use super::ConfigSet;
pub use super::NoOpts;
pub use super::Repo;
pub use super::Result;
pub use super::IO;

commands! {
    mod args;
    mod causerusterror;
    mod dumpdynamicconfig;
    mod dumpindexedlog;
    mod dumptrace;
    mod dynamicconfig;
    mod fsync;
    mod http;
    mod scmstore;
    mod scmstorereplay;
    mod python;
    mod racyoutput;
    mod runlog;
    mod segmentclone;
    mod segmentgraph;
    mod segmentpull;
    mod store;
    mod top;
}

define_flags! {
    pub struct DebugArgsOpts {
        #[args]
        args: Vec<String>,
    }
}
