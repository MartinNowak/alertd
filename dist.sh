#!/bin/sh

set -ueo pipefail

DUB=${DUB:=dub}
BUILD=${BUILD:=release}

npm install
npm run build
if [ ! -f sqlite3.o ]; then
    curl -O https://www.sqlite.org/2016/sqlite-amalgamation-3110000.zip
    unzip -o sqlite-amalgamation-3110000.zip sqlite-amalgamation-3110000/sqlite3.c
    cc -O2 -c sqlite-amalgamation-3110000/sqlite3.c
    rm -rf sqlite-amalgamation-3110000.zip sqlite-amalgamation-3110000
fi
$DUB build --build=$BUILD
if [ $BUILD = release ]; then
    strip alertd
fi

ver=$(git describe)
name=alertd-${ver#v}-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
tar --transform "s|^|$name/|" -Jcf $name.tar.xz alertd alertd.sample.json dist/
