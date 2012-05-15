#!/bin/sh
mkdir -p m4
autoreconf -fiv -Wall || exit
./configure --enable-maintainer-mode "$@"
