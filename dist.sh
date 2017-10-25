#!/bin/sh

set -ueo pipefail

vagrant up

cat | vagrant ssh --command 'bash -s -' <<EOF
cd /vagrant

cd frontend
npm install
./node_modules/.bin/ng build --prod --aot
cd ..

source \$(curl -fsS https://dlang.org/install.sh | bash -s dmd-2.076.1 --activate)

dub build --build=release
strip alertd

ver=$(git describe)
name=alertd-\${ver#v}-\$(uname -s | tr '[:upper:]' '[:lower:]')-\$(uname -m)
tar --exclude='*.map' --transform "s|^|\$name/|" -Jcf \$name.tar.xz alertd alertd.sample.json dist/
EOF

vagrant destroy -f
