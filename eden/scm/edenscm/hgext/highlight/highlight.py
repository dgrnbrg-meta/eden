# Portions Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# highlight.py - highlight extension implementation file
#
#  Copyright 2007-2009 Adam Hupp <adam@hupp.org> and others
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
#
# The original module was split in an interface and an implementation
# file to defer pygments loading and speedup extension setup.

from __future__ import absolute_import

from edenscm.mercurial import demandimport, encoding, util


demandimport.ignore.extend(["pkgutil", "pkg_resources", "__main__"])


with demandimport.deactivated():
    import pygments
    import pygments.formatters
    import pygments.lexers
    import pygments.util


highlight = pygments.highlight
ClassNotFound = pygments.util.ClassNotFound
guess_lexer = pygments.lexers.guess_lexer
guess_lexer_for_filename = pygments.lexers.guess_lexer_for_filename
TextLexer = pygments.lexers.TextLexer
HtmlFormatter = pygments.formatters.HtmlFormatter

SYNTAX_CSS = '\n<link rel="stylesheet" href="{url}highlightcss" ' 'type="text/css" />'


def pygmentize(field, fctx, style, tmpl, guessfilenameonly=False):

    # append a <link ...> to the syntax highlighting css
    old_header = tmpl.load("header")
    if SYNTAX_CSS not in old_header:
        new_header = old_header + SYNTAX_CSS
        tmpl.cache["header"] = new_header

    text = fctx.data()
    if util.binary(text):
        return

    # str.splitlines() != unicode.splitlines() because "reasons"
    for c in "\x0c\x1c\x1d\x1e":
        if c in text:
            text = text.replace(c, "")

    # Pygments is best used with Unicode strings:
    # <http://pygments.org/docs/unicode/>
    text = text.decode(encoding.encoding, "replace")

    # To get multi-line strings right, we can't format line-by-line
    try:
        lexer = guess_lexer_for_filename(fctx.path(), text[:1024], stripnl=False)
    except (ClassNotFound, ValueError):
        # guess_lexer will return a lexer if *any* lexer matches. There is
        # no way to specify a minimum match score. This can give a high rate of
        # false positives on files with an unknown filename pattern.
        if guessfilenameonly:
            return

        try:
            lexer = guess_lexer(text[:1024], stripnl=False)
        except (ClassNotFound, ValueError):
            # Don't highlight unknown files
            return

    # Don't highlight text files
    if isinstance(lexer, TextLexer):
        return

    formatter = HtmlFormatter(nowrap=True, style=style)

    colorized = highlight(text, lexer, formatter)
    coloriter = (s.encode(encoding.encoding, "replace") for s in colorized.splitlines())

    tmpl.filters["colorize"] = lambda x: next(coloriter)

    oldl = tmpl.cache[field]
    newl = oldl.replace("line|escape", "line|colorize")
    tmpl.cache[field] = newl
