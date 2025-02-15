# Copyright (c) Facebook, Inc. and its affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# gitlookup.py - server-side support for hg->git and git->hg lookups

""" extension that will look up hashes from an hg-git map file over the wire.
    This also provides client and server commands to download all the Git
    metadata via bundle2. Example usage:

    - get the git equivalent of hg 47d743e068523a9346a5ea4e429eeab185c886c6

        hg identify --id -r\\
            _gitlookup_hg_47d743e068523a9346a5ea4e429eeab185c886c6\\
            ssh://server/repo

    - get the hg equivalent of git 6916a3c30f53878032dea8d01074d8c2a03927bd

        hg identify --id -r\\
            _gitlookup_git_6916a3c30f53878032dea8d01074d8c2a03927bd\\
            ssh://server/repo

::

    [gitlookup]
    # Define the location of the map file with the mapfile config option.
    mapfile = <location of map file>

    # The config option onlymapdelta controls how the server handles the hg-git
    # map. A True value corresponds to serving only missing map data while False
    # corresponds to serving the complete map.
    onlymapdelta = False
    # Some repos might have missing hashes in the gitmap and there is no way
    # to go back and fix them. We can safely skip them in the verification part
    # of gitgetmeta.
    skiphashes = []

"""

import errno
from typing import Optional

import bindings
from edenscm.mercurial import (
    bundle2,
    encoding,
    error,
    exchange,
    extensions,
    hg,
    json,
    localrepo,
    pycompat,
    registrar,
    util,
    wireproto,
)
from edenscm.mercurial.i18n import _
from edenscm.mercurial.node import bin, hex, nullid


cmdtable = {}
command = registrar.command(cmdtable)


def wrapwireprotocommand(command, wrapper):
    """Wrap the wire proto command named `command' in table

    Just like extensions.wrapcommand, except for wire protocol commands.
    """
    assert util.safehasattr(wrapper, "__call__")
    origfn, args = wireproto.commands[command]

    def wrap(*args, **kwargs):
        return util.checksignature(wrapper)(
            util.checksignature(origfn), *args, **kwargs
        )

    wireproto.commands[command] = wrap, args
    return wrapper


def remotelookup(orig, repo, proto, key):
    k = encoding.tolocal(key)
    if k.startswith("_gitlookup_"):
        ret = _dolookup(repo, k)
        if ret is not None:
            success = 1
        else:
            success = 0
            ret = "gitlookup failed"
        return "%s %s\n" % (success, ret)
    return orig(repo, proto, key)


def locallookup(orig, repo, key):
    gitlookup = _dolookup(repo, key)
    if gitlookup:
        return bin(gitlookup)
    else:
        return orig(repo, key)


def _dolookup(repo, key):
    mapfile = repo.ui.configpath("gitlookup", "mapfile")
    if mapfile is None:
        return None
    if not isinstance(key, str):
        return None
    # direction: git to hg = g, hg to git = h
    if key.startswith("_gitlookup_git_"):
        direction = "tohg"
        sha = key[15:]
    elif key.startswith("_gitlookup_hg_"):
        direction = "togit"
        sha = key[14:]
    else:
        return None
    if direction == "togit":
        # we've started recording the hg hash in extras.
        try:
            ctx = repo[sha]
        except error.RepoLookupError as e:
            if "unknown revision" in str(e):
                return None
            raise e
        fromextra = ctx.extra().get("convert_revision", "")
        if fromextra:
            return fromextra

    # Do not lookup for uninteresting names like "gfoobar".
    if len(sha) != 40:
        return None

    # Attempt to use the nodemap index.
    # internal config: gitlookup.useindex
    if repo.ui.configbool("gitlookup", "useindex", False):
        nodemap = gitnodemap(repo)
        uptodate = False
        try:
            nodemap.build(repo)
            uptodate = True
        except Exception as ex:
            # Not fatal. But fallback to flat mapfile if nothing found.
            repo.ui.write_err(_("failed to update git nodemap: %s\n") % ex)
        node = bin(sha)
        if direction == "togit":
            result = nodemap.getgitnode(node)
        else:
            result = nodemap.gethgnode(node)
        if result:
            return hex(result)
        if uptodate:
            # The nodemap is complete. No need to try the flat mapfile.
            return None

    # Flat mapfile - can be very slow.
    hggitmap = open(mapfile, "rb")
    for line in hggitmap:
        line = pycompat.decodeutf8(line)
        gitsha, hgsha = line.strip().split(" ", 1)
        if direction == "tohg" and sha == gitsha:
            return hgsha
        if direction == "togit" and sha == hgsha:
            return gitsha
    return None


@command("gitgetmeta", [], "[SOURCE]")
def gitgetmeta(ui, repo, source="default"):
    """get git metadata from a server that supports fb_gitmeta"""
    source, branch = hg.parseurl(ui.expandpath(source))
    other = hg.peer(repo, {}, source)
    ui.status(_("getting git metadata from %s\n") % util.hidepassword(source))

    kwargs = {"bundlecaps": exchange.caps20to10(repo)}
    capsblob = bundle2.encodecaps(bundle2.getrepocaps(repo))
    kwargs["bundlecaps"].add("bundle2=" + util.urlreq.quote(capsblob))
    # this would ideally not be in the bundlecaps at all, but adding new kwargs
    # for wire transmissions is not possible as of Mercurial d19164a018a1
    kwargs["bundlecaps"].add("fb_gitmeta")
    kwargs["heads"] = [nullid]
    kwargs["cg"] = False
    kwargs["common"] = _getcommonheads(repo)
    bundle = other.getbundle("pull", **kwargs)
    try:
        op = bundle2.processbundle(repo, bundle)
    except error.BundleValueError as exc:
        raise error.Abort("missing support for %s" % exc)
    writebytes = op.records["fb:gitmeta:writebytes"]
    ui.status(_("wrote %d files (%d bytes)\n") % (len(writebytes), sum(writebytes)))


@command("debugbuildgitnodemap")
def debugbuildgitnodemap(ui, repo):
    """build indexes for git <-> hg commit translation"""
    nodemap = gitnodemap(repo)
    count = nodemap.build(repo)
    ui.write(_("%s new commits are indexed\n") % count)


hgheadsfile = "git-synced-hgheads"
gitmapfile = "git-mapfile"
gitmetafiles = set([gitmapfile, "git-named-branches", "git-tags", "git-remote-refs"])

LASTREVFILE = "git-nodemap-lastrev"
MAPFILE = "git-nodemap"


class gitnodemap(object):
    def __init__(self, repo):
        self.lastrev = int(repo.localvfs.tryread(LASTREVFILE) or "0")
        self.map = bindings.nodemap.nodemap(repo.localvfs.join(MAPFILE))

    def build(self, repo) -> int:
        """Build the nodemap incrementally.
        Assume there is no changelog truncation.
        Return number of revs built.
        """
        repolen = len(repo)
        if self.lastrev >= repolen:
            return 0
        with repo.wlock():
            self.map.flush()  # reload data
            self.lastrev = int(repo.localvfs.tryread(LASTREVFILE) or "0")
            if self.lastrev >= repolen:
                return 0
            ui = repo.ui
            mapadd = self.map.add
            maplookup = self.map.lookupbysecond
            mapfile = repo.ui.configpath("gitlookup", "mapfile") or repo.localvfs.join(
                gitmapfile
            )
            if self.lastrev == 0 and repolen > 0 and mapfile:
                # Initial import from flat mapfile
                ui.status(_("importing git nodemap from flat mapfile\n"))
                for line in open(mapfile, "r"):
                    githexnode, hghexnode = line.split()
                    mapadd(bin(githexnode), bin(hghexnode))
            unfi = repo
            clnode = unfi.changelog.node
            clrevision = unfi.changelog.changelogrevision
            # Read git hashes from commit extras.
            # Assume the initial import covers all commits without using commit extras.
            revs = range(self.lastrev, repolen)
            if revs:
                ui.status(_("building git nodemap for %s commits\n") % (len(revs),))
                for rev in revs:
                    hgnode = clnode(rev)
                    if maplookup(hgnode):
                        continue
                    githexnode = clrevision(rev).extra.get("convert_revision")
                    if githexnode:
                        gitnode = bin(githexnode)
                        mapadd(gitnode, hgnode)
            self.map.flush()
            repo.localvfs.write(LASTREVFILE, str(repolen))
            self.lastrev = repolen
            return len(revs)

    def gethgnode(self, gitnode: bytes) -> "Optional[bytes]":
        return self.map.lookupbyfirst(gitnode)

    def getgitnode(self, hgnode: bytes) -> "Optional[bytes]":
        return self.map.lookupbyfirst(hgnode)


def _getfile(repo, filename):
    try:
        return repo.localvfs(filename)
    except (IOError, OSError) as e:
        if e.errno != errno.ENOENT:
            repo.ui.warn(_("warning: unable to read %s: %s\n") % (filename, e))

    return None


def _getcommonheads(repo):
    commonheads = []
    f = _getfile(repo, hgheadsfile)
    if f:
        commonheads = f.readlines()
        commonheads = [bin(x.strip()) for x in commonheads]
    return commonheads


def _isheadmissing(repo, heads):
    return not all(repo.known(heads))


def _getmissinglines(mapfile, missinghashes):
    missinglines = set()

    # Avoid expensive lookup through the map file if there is no missing hash.
    if not missinghashes:
        return missinglines

    linelen = 82
    hashestofind = missinghashes.copy()
    content = pycompat.decodeutf8(mapfile.read())
    if len(content) % linelen != 0:
        raise error.Abort(_("gitmeta: invalid mapfile length (%s)") % len(content))

    # Walk backwards through the map file, since recent commits are added at the
    # end.
    count = int(len(content) / linelen)
    for i in range(count - 1, -1, -1):
        offset = i * linelen
        line = content[offset : offset + linelen]
        hgsha = line[41:81]
        if hgsha in hashestofind:
            missinglines.add(line)

            # Return the missing lines if we found all of them.
            hashestofind.remove(hgsha)
            if not hashestofind:
                return missinglines

    raise error.Abort(_("gitmeta: missing hashes in file %s") % mapfile.name)


class _githgmappayload(object):
    def __init__(self, needfullsync, newheads, missinglines):
        self.needfullsync = needfullsync
        self.newheads = newheads
        self.missinglines = missinglines

    def _todict(self):
        d = {}
        d["needfullsync"] = self.needfullsync
        d["newheads"] = list(self.newheads)
        d["missinglines"] = list(self.missinglines)
        return d

    def tojson(self):
        return json.dumps(self._todict())

    @classmethod
    def _fromdict(cls, d):
        needfullsync = d["needfullsync"]
        newheads = set(d["newheads"])
        missinglines = set(d["missinglines"])
        return cls(needfullsync, newheads, missinglines)

    @classmethod
    def fromjson(cls, jsonstr):
        d = json.loads(jsonstr)
        return cls._fromdict(d)


def _exchangesetup():
    @exchange.getbundle2partsgenerator("b2x:fb:gitmeta:githgmap")
    def _getbundlegithgmappart(bundler, repo, source, bundlecaps=None, **kwargs):
        """send missing git to hg map data via bundle2"""
        if "fb_gitmeta" in bundlecaps:
            # Do nothing if the config indicates serving the complete git-hg map
            # file. _getbundlegitmetapart will handle serving the complete file in
            # this case.
            if not repo.ui.configbool("gitlookup", "onlymapdelta", False):
                return

            mapfile = _getfile(repo, gitmapfile)
            if not mapfile:
                return

            commonheads = kwargs["common"]

            # If there are missing heads, we will sync everything.
            if _isheadmissing(repo, commonheads):
                commonheads = []

            needfullsync = len(commonheads) == 0

            heads = repo.heads()
            newheads = set(hex(head) for head in heads)

            missingcommits = repo.changelog.findmissing(commonheads, heads)
            missinghashes = set(hex(commit) for commit in missingcommits)
            missinghashes.difference_update(
                set(repo.ui.configlist("gitlookup", "skiphashes", []))
            )
            missinglines = _getmissinglines(mapfile, missinghashes)

            payload = _githgmappayload(needfullsync, newheads, missinglines)
            serializedpayload = pycompat.encodeutf8(payload.tojson())
            part = bundle2.bundlepart(
                "b2x:fb:gitmeta:githgmap",
                [("filename", gitmapfile)],
                data=serializedpayload,
            )

            bundler.addpart(part)

    @exchange.getbundle2partsgenerator("b2x:fb:gitmeta")
    def _getbundlegitmetapart(bundler, repo, source, bundlecaps=None, **kwargs):
        """send git metadata via bundle2"""
        if "fb_gitmeta" in bundlecaps:
            filestooverwrite = gitmetafiles

            # Exclude the git-hg map file if the config indicates that the server
            # should only be serving the missing map data. _getbundle2partsgenerator
            # will serve the missing map data in this case.
            if repo.ui.configbool("gitlookup", "onlymapdelta", False):
                filestooverwrite = filestooverwrite - set([gitmapfile])

            for fname in sorted(filestooverwrite):
                f = _getfile(repo, fname)
                if not f:
                    continue

                part = bundle2.bundlepart(
                    "b2x:fb:gitmeta", [("filename", fname)], data=f.read()
                )
                bundler.addpart(part)


def _writefile(op, filename, data):
    with op.repo.localvfs(filename, "w+", atomictemp=True) as f:
        op.repo.ui.note(_("writing .hg/%s\n") % filename)
        f.write(data)
        op.records.add("fb:gitmeta:writebytes", len(data))


def _validatepartparams(op, params):
    if "filename" not in params:
        raise error.Abort(_("gitmeta: 'filename' missing"))

    fname = params["filename"]
    if fname not in gitmetafiles:
        op.repo.ui.warn(_("warning: gitmeta: unknown file '%s' skipped\n") % fname)
        return False

    return True


def _bundlesetup():
    @bundle2.parthandler("b2x:fb:gitmeta:githgmap", ("filename",))
    @bundle2.parthandler("fb:gitmeta:githgmap", ("filename",))
    def bundle2getgithgmap(op, part):
        params = dict(part.mandatoryparams)
        if _validatepartparams(op, params):
            filename = params["filename"]
            with op.repo.wlock():
                data = _githgmappayload.fromjson(pycompat.decodeutf8(part.read()))
                missinglines = data.missinglines

                # No need to update anything if already in sync.
                if not missinglines:
                    return

                if data.needfullsync:
                    newlines = missinglines
                else:
                    mapfile = _getfile(op.repo, filename)
                    if mapfile:
                        currentlines = set(
                            pycompat.decodeutf8(l) for l in mapfile.readlines()
                        )
                        if currentlines & missinglines:
                            msg = "warning: gitmeta: unexpected lines in .hg/%s\n"
                            op.repo.ui.warn(_(msg) % filename)

                        currentlines.update(missinglines)
                        newlines = currentlines
                    else:
                        raise error.Abort(
                            _("gitmeta: could not read from .hg/%s") % filename
                        )

                _writefile(op, filename, pycompat.encodeutf8("".join(newlines)))
                _writefile(
                    op, hgheadsfile, pycompat.encodeutf8("\n".join(data.newheads))
                )

    @bundle2.parthandler("b2x:fb:gitmeta", ("filename",))
    @bundle2.parthandler("fb:gitmeta", ("filename",))
    def bundle2getgitmeta(op, part):
        """unbundle a bundle2 containing git metadata on the client"""
        params = dict(part.mandatoryparams)
        if _validatepartparams(op, params):
            filename = params["filename"]
            with op.repo.wlock():
                data = part.read()
                _writefile(op, filename, data)


def extsetup(ui):
    wrapwireprotocommand("lookup", remotelookup)
    extensions.wrapfunction(localrepo.localrepository, "lookup", locallookup)
    _exchangesetup()
    _bundlesetup()
