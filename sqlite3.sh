#!/bin/sh

if [ ! -f sqlite3.o ]; then
    wget -c https://www.sqlite.org/2016/sqlite-amalgamation-3110000.zip
    unzip -o sqlite-amalgamation-3110000.zip sqlite-amalgamation-3110000/sqlite3.c
    cc -O2 -c sqlite-amalgamation-3110000/sqlite3.c
    rm -rf sqlite-amalgamation-3110000
fi
