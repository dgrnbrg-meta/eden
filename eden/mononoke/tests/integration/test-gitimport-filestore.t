# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ FILESTORE=1
  $ FILESTORE_CHUNK_SIZE=10
  $ . "${TEST_FIXTURES}/library.sh"
  $ ENABLED_DERIVED_DATA='["git_trees", "filenodes", "hgchangesets"]' setup_common_config
  $ GIT_REPO="${TESTTMP}/repo-git"
  $ HG_REPO="${TESTTMP}/repo-hg"

# Setup git repsitory
  $ mkdir "$GIT_REPO"
  $ cd "$GIT_REPO"
  $ git init -q
  $ echo "laaaaaaaaaarge file" > file1
  $ git add file1
  $ git commit -am "Add file1"
  [master (root-commit) 0ecc922] Add file1
   1 file changed, 1 insertion(+)
   create mode 100644 file1

# Import it into Mononoke
  $ cd "$TESTTMP"
  $ gitimport "$GIT_REPO" --derive-trees --derive-hg --hggit-compatibility --bonsai-git-mapping full-repo
  * using repo "repo" repoid RepositoryId(0) (glob)
  * GitRepo:*repo-git commit 1 of 1 - Oid:* => Bid:* (glob)
  * 1 tree(s) are valid! (glob)
  * Hg: 0ecc922af7b11d796a715f3c093673914b060164: HgManifestId(HgNodeHash(Sha1(4f16e4ceeccf36b18e4a72e183c16a9bea650e1d))) (glob)
  * Ref: Some("refs/heads/master"): Some(ChangesetId(Blake2(306010a179d752b69fa2dd068a3fab8077043c217d3fb7370f705a50acbef48c))) (glob)

  $ mononoke_admin filestore is-chunked id 48ef00ac63821b09154b55f1b380d253f936afb076a873e1bcc1d137c8b5bab2
  * using repo "repo" repoid RepositoryId(0) (glob)
  chunked
