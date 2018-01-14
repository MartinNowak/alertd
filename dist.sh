#!/bin/sh

set -xue

cd frontend && npm install && ./node_modules/.bin/ng build --prod --aot && cd ..
gzip -9 --keep dist/*.css dist/*.js

. ~/dlang/*/activate

dub build --build=release
strip alertd

ver=$(git describe)
name=alertd-${ver#v}-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
tar --exclude='*.map' --transform "s|^|$name/|" -Jcf $name.tar.xz alertd alertd.sample.json dist/

echo 'Build finished, run the following command to grab the tar archive.'
echo "  docker cp $HOSTNAME:$PWD/$name.tar.xz ."
echo 'Press Enter to exit container'
read _
