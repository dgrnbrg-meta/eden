#if no-osx
  $ mkcommit() {
  >    echo "$1" > "$1"
  >    hg add "$1"
  >    hg ci -d "0 0" -m "$1"
  > }
  $ . "$TESTDIR/infinitepush/library.sh"
  $ setupcommon

With no configuration it should abort
  $ hg init server
  $ cd server
  $ setupsqlserverhgrc babar
  $ hg st
  abort: please set infinitepush.sqlhost
  [255]
  $ setupdb
  $ cd ..
  $ hg clone -q ssh://user@dummy/server client1
  $ hg clone -q ssh://user@dummy/server client2
  $ cd client1
  $ setupsqlclienthgrc
  $ cd ../client2
  $ setupsqlclienthgrc
  $ cd ../client1
  $ mkcommit scratchcommit

  $ hg push -r . --to scratch/book --create
  pushing to ssh://user@dummy/server
  searching for changes
  remote: pushing 1 commit:
  remote:     2d9cfa751213  scratchcommit

Make pull and check that scratch commit is not pulled
  $ cd ../client2
  $ hg pull
  pulling from ssh://user@dummy/server
  no changes found
  $ hg log -r scratch/book
  abort: unknown revision 'scratch/book'!
  [255]

Pull scratch commit from the second client
  $ hg pull -B scratch/book
  pulling from ssh://user@dummy/server
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 2d9cfa751213
  (run 'hg update' to get a working copy)
  $ hg up scratch/book
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark scratch/book)
  $ hg log -G
  @  changeset:   0:2d9cfa751213
     bookmark:    scratch/book
     tag:         tip
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     scratchcommit
  
  $ cd ../server
  $ hg book scratch/%erversidebook
  $ hg book serversidebook
  $ cd ../client1
  $ hg book --list-remote 'scratch/*'
     scratch/%erversidebook    0000000000000000000000000000000000000000
     scratch/book              2d9cfa7512136a84a6edb6a7c288145229c2ef7f
  $ hg book --list-remote 'scratch/%*'
     scratch/%erversidebook    0000000000000000000000000000000000000000
  $ mysql -h $DBHOST -P $DBPORT -D $DBNAME -u $DBUSER $DBPASSOPT -e 'select * from nodesmetadata'
  node	message	p1	p2	author	committer	author_date	committer_date	reponame	optional_json_metadata
  2d9cfa7512136a84a6edb6a7c288145229c2ef7f	scratchcommit	0000000000000000000000000000000000000000	0000000000000000000000000000000000000000	test	test	0	0	babar	NULL
  $ cd ../server
  $ hg debugfillinfinitepushmetadata --node 2d9cfa7512136a84a6edb6a7c288145229c2ef7f
  $ mysql -h $DBHOST -P $DBPORT -D $DBNAME -u $DBUSER $DBPASSOPT -e 'select * from nodesmetadata'
  node	message	p1	p2	author	committer	author_date	committer_date	reponame	optional_json_metadata
  2d9cfa7512136a84a6edb6a7c288145229c2ef7f	scratchcommit	0000000000000000000000000000000000000000	0000000000000000000000000000000000000000	test	test	0	0	babar	{"changed_files": {"scratchcommit": {"adds": 1, "isbinary": false, "removes": 0, "status": "added"}}}

  $ cd ../
  $ rm -rf client1 && rm -rf client2

Test ordering of hosts and reporoot in pullbackup
Expected result:
repo roots must be ordered in MRU order (the way the the most recent used come first)
Since bookmarkstonode mysql table uses '`time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'
with second resolution instead of an AUTO_INCREMENT column,
sleeps should be used to get predictable order
  $ hg clone -q ssh://user@dummy/server client1
  $ cd client1 && setupsqlclienthgrc
  $ mkcommit 'Commit in repo client1'
  $ sleep 1
  $ hg pushb -q --config infinitepushbackup.hostname=mydevhost
  $ cd ..
  $ hg clone -q ssh://user@dummy/server client2
  $ cd client2 && setupsqlclienthgrc
  $ mkcommit 'Commit in repo client2'
  $ sleep 1
  $ hg pushb -q --config infinitepushbackup.hostname=devhost
  $ cd ..
  $ hg clone -q ssh://user@dummy/server client3
  $ cd client3 && setupsqlclienthgrc
  $ mkcommit 'Commit in repo client3'
  $ sleep 1
  $ hg pushb -q --config infinitepushbackup.hostname=devhost
  $ cd ..
  $ hg clone -q ssh://user@dummy/server client4
  $ cd client4 && setupsqlclienthgrc
  $ mkcommit 'Commit in repo client4'
  $ sleep 1
  $ hg pushb -q --config infinitepushbackup.hostname=mydevhost
  $ hg pullbackup
  abort: ambiguous hostname to restore:
  mydevhost
  devhost
  (set --hostname to disambiguate)
  [255]
  $ hg pullbackup --hostname mydevhost
  abort: ambiguous repo root to restore:
  $TESTTMP/client4
  $TESTTMP/client1
  (set --reporoot to disambiguate)
  [255]
  $ hg pullbackup --reporoot $TESTTMP/client1 -q
  $ hg pullbackup --reporoot $TESTTMP/client2 -q
  $ hg pullbackup --reporoot $TESTTMP/client3 -q
  $ hg log -G --template "{node|short} '{desc}'\n"
  o  8b99f4b01a41 'Commit in repo client3'
  
  o  c25c4d010d8e 'Commit in repo client2'
  
  o  250e5455acab 'Commit in repo client1'
  
  @  3309f3c00117 'Commit in repo client4'
  

Getavailablebackups should also go in MRU order
  $ hg getavailablebackups --json
  {
      "mydevhost": [
          "$TESTTMP/client4", 
          "$TESTTMP/client1"
      ], 
      "devhost": [
          "$TESTTMP/client3", 
          "$TESTTMP/client2"
      ]
  }
  $ hg getavailablebackups
  user test has 4 available backups:
  (backups are ordered, the most recent are at the top of the list)
  $TESTTMP/client4 on mydevhost
  $TESTTMP/client3 on devhost
  $TESTTMP/client2 on devhost
  $TESTTMP/client1 on mydevhost
#endif
