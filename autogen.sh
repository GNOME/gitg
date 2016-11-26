#!/bin/sh
# Run this to generate all the initial makefiles, etc.

test -n "$srcdir" || srcdir=`dirname "$0"`
test -n "$srcdir" || srcdir=.

olddir=`pwd`
cd "$srcdir"

INTLTOOLIZE=`which intltoolize`
if test -z $INTLTOOLIZE; then
        echo "*** No intltoolize found, please install the intltool package ***"
        exit 1
fi

AUTORECONF=`which autoreconf`
if test -z $AUTORECONF; then
        echo "*** No autoreconf found, please install it ***"
        exit 1
fi

if test -z `which autopoint`; then
        echo "*** No autopoint found, please install it ***"
        exit 1
fi

LIBTOOL=`which libtoolize`
if test -z $LIBTOOL; then
        echo "*** No libtool found, please install it ***"
        exit 1
fi

if ! test -z `which git` && test -d .git; then
        git submodule update --init --recursive

        if [ $? != 0 ]; then
            echo "*** Failed to download submodules. Maybe you have a bad connection or a submodule was not forked?"
            exit 1
        fi
fi

autopoint --force
AUTOPOINT='intltoolize --automake --copy' autoreconf --force --install --verbose

cd "$olddir"
test -n "$NOCONFIGURE" || "$srcdir/configure" "$@"
