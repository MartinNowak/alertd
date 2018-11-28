#!/bin/sh

if [ ! -f sqlite3.o ]; then
    wget -c https://www.sqlite.org/2018/sqlite-autoconf-3250300.tar.gz
    tar -zxf sqlite-autoconf-3250300.tar.gz
    cc -O2 -c -fPIC sqlite-autoconf-3250300/sqlite3.c
    rm -rf sqlite-autoconf-3250300
fi
