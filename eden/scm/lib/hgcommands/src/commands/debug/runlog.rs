/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::io::Write;

use anyhow::Result;
use clidispatch::errors;
use clidispatch::io::IO;
use cliparser::define_flags;
use repo::repo::Repo;

define_flags! {
    pub struct DebugRunlogOpts {
        /// display entries for exited/crashed commands (ADVANCED)
        ended: bool,

        /// output template (only allows "json")
        #[short('T')]
        template: String,
    }
}

enum Format {
    Text,
    Json,
}

pub fn run(opts: DebugRunlogOpts, io: &IO, repo: Repo) -> Result<u8> {
    let mut stdout = io.output();
    let mut stderr = io.error();

    let format = match opts.template.as_str() {
        "json" => Format::Json,
        "" => Format::Text,
        _ => return Err(errors::Abort("invalid template (only \"json\" supported)".into()).into()),
    };

    for entry in runlog::FileStore::entry_iter(repo.shared_dot_hg_path())? {
        let (entry, running) = match entry {
            Ok((entry, running)) => (entry, running),
            Err(err) => {
                // Unlikely, but it is possible to have incomplete Json files.
                write!(stderr, "Error reading runlog entry: {:?}\n", err)?;
                continue;
            }
        };

        if opts.ended == running {
            continue;
        }

        match format {
            Format::Text => {
                write!(stdout, "{:#?}\n", entry)?;
            }
            Format::Json => {
                serde_json::to_writer(&mut stdout, &entry)?;
                stdout.write_all(&[b'\n'])?;
            }
        }
    }

    Ok(0)
}

pub fn name() -> &'static str {
    "debugrunlog"
}

pub fn doc() -> &'static str {
    "display runlog entries"
}
