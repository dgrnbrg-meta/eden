#!/usr/bin/env bash
# Portions Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Copyright 2006, 2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

hg init rebase
cd rebase

#  @  7: 'H'
#  |
#  | o  6: 'G'
#  |/|
#  o |  5: 'F'
#  | |
#  | o  4: 'E'
#  |/
#  | o  3: 'D'
#  | |
#  | o  2: 'C'
#  | |
#  | o  1: 'B'
#  |/
#  o  0: 'A'

echo A > A
hg ci -Am A
echo B > B
hg ci -Am B
echo C > C
hg ci -Am C
echo D > D
hg ci -Am D
hg up -q -C 0
echo E > E
hg ci -Am E
hg up -q -C 0
echo F > F
hg ci -Am F
hg merge -r 4
hg ci -m G
hg up -q -C 5
echo H > H
hg ci -Am H

hg bundle -a ../rebase.hg

cd ..
rm -Rf rebase
