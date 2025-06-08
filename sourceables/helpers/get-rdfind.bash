#!/usr/bin/env bash
set -e
apt install -y unzip build-essential automake nettle-dev
CWD=$(pwd)
TMP_DIR='/tmp/rdfind-setup'
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"
wget 'https://github.com/pauldreik/rdfind/archive/refs/tags/releases/1.7.0.zip'
unzip *.zip
rm *.zip
cd *
./bootstrap.sh
./configure
make
make install
exit #?
