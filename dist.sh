#!/bin/sh

set -ueo pipefail

DUB=${DUB:=dub}
BUILD=${BUILD:=release}

npm install
./node_modules/.bin/webpack -p
rm -rf dist
mkdir -p public
./node_modules/.bin/yuglify build/{vendor,bundle}.js node_modules/highcharts/highcharts.js --combine public/app
./node_modules/.bin/yuglify node_modules/skeleton-css/css/{normalize.css,skeleton.css} fonts/raleway.css --combine public/app
cp fonts/Raleway-Regular.woff public/
curl -O https://www.sqlite.org/2016/sqlite-amalgamation-3110000.zip
unzip -o sqlite-amalgamation-3110000.zip sqlite-amalgamation-3110000/sqlite3.c
cc -O2 -c sqlite-amalgamation-3110000/sqlite3.c
rm -rf sqlite-amalgamation-3110000.zip sqlite-amalgamation-3110000
$DUB build --build=$BUILD
strip alertd

ver=$(git describe)
name=alertd-${ver#v}-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
tar --transform "s|^|$name/|" -Jcf $name.tar.xz alertd alertd.sample.json public/
