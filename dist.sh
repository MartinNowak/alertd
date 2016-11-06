#!/bin/sh

set -ueo pipefail

DUB=${DUB:=dub}
BUILD=${BUILD:=release}

npm install
npm run build
$DUB build --build=$BUILD
if [ $BUILD = release ]; then
    strip alertd
fi

ver=$(git describe)
name=alertd-${ver#v}-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
tar --transform "s|^|$name/|" -Jcf $name.tar.xz alertd alertd.sample.json dist/
