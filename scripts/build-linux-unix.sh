#!/bin/sh
# Linux/Unix full build: HOST = TARGET (native). See Cross-compiling Part B for theory.
#
# Problem: GNU make prefers src/GNUmakefile over Makefile. A leftover Windows
# MinGW file (gitignored) forces Win32 compile in WSL and breaks (e.g. io.h).
#
# Usage (from repo root, WSL or Linux):
#   sh scripts/build-linux-unix.sh

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rm -f src/GNUmakefile
rm -f src/GNUmakefile.depend

cd sys/unix
sh setup.sh hints/linux.500
cd "$ROOT"

make fetch-lua
make all

echo "Done: ./src/nethack (install optional: make install)."
