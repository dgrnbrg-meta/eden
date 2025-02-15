# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

from __future__ import absolute_import, division, print_function, unicode_literals

import argparse
import os
import pathlib
import subprocess
import sys
from typing import List, Union

from . import subcmd as subcmd_mod
from .cmd_util import require_checkout
from .subcmd import Subcmd


trace_cmd = subcmd_mod.Decorator()


def get_trace_stream_command() -> pathlib.Path:
    # TODO(T111405470) Rewrite in rust so we can avoid hardcoding these paths
    try:
        return pathlib.Path(os.environ["EDENFS_TRACE_STREAM"])
    except KeyError:
        if sys.platform == "win32":
            return pathlib.Path("C:/tools/eden/libexec/trace_stream.exe")
        return pathlib.Path("/usr/local/libexec/eden/eden_trace_stream")


def execute_cmd(arg_list: List[Union[pathlib.Path, str]]) -> int:
    if sys.platform == "win32":
        return subprocess.call(arg_list)
    else:
        encoded_args = [os.fsencode(arg) for arg in arg_list]
        os.execv(
            arg_list[0],
            encoded_args,
        )


@trace_cmd("hg", "Trace hg object fetches")
class TraceHgCommand(Subcmd):
    def setup_parser(self, parser: argparse.ArgumentParser) -> None:
        parser.add_argument(
            "checkout", default=None, nargs="?", help="Path to the checkout"
        )

    async def run(self, args: argparse.Namespace) -> int:
        instance, checkout, _rel_path = require_checkout(args, args.checkout)
        trace_stream_command = get_trace_stream_command()
        return execute_cmd(
            [
                trace_stream_command,
                "--mountRoot",
                checkout.path,
                "--trace=hg",
            ]
        )


@trace_cmd("fs", "Monitor filesystem requests.")
class TraceFsCommand(Subcmd):
    def setup_parser(self, parser: argparse.ArgumentParser) -> None:
        parser.add_argument(
            "checkout", default=None, nargs="?", help="Path to the checkout"
        )
        parser.add_argument(
            "--reads",
            action="store_true",
            default=False,
            help="Limit trace to read operations",
        )
        parser.add_argument(
            "--writes",
            action="store_true",
            default=False,
            help="Limit trace to write operations",
        )

    async def run(self, args: argparse.Namespace) -> int:
        instance, checkout, _rel_path = require_checkout(args, args.checkout)
        trace_stream_command = get_trace_stream_command()
        return execute_cmd(
            [
                trace_stream_command,
                "--mountRoot",
                checkout.path,
                "--trace=fs",
                f"--reads={'true' if args.reads else 'false'}",
                f"--writes={'true' if args.writes else 'false'}",
            ]
        )
