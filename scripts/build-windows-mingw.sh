#!/bin/sh
# Windows MinGW-w64 full build (GNU make + gcc). Typical shell: MSYS2 UCRT64 or MINGW64.
#
# Cross-compiling Part B is for HOST!=TARGET; here HOST=TARGET (Windows native).
#
# Prerequisites (MSYS2 example):
#   pacman -S mingw-w64-ucrt-x86_64-gcc git make curl tar gettext
#
# Usage (from repo root, inside MSYS2 MinGW shell):
#   sh scripts/build-windows-mingw.sh
#
# HanNetHack: GNU make prefers plain src/GNUmakefile and breaks Linux/WSL builds.
# This script uses sys/windows/GNUmakefile as src/GNUmakefile.win and runs
# make -f GNUmakefile.win. Include file must be src/GNUmakefile.depend .

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "$(uname -s 2>/dev/null)" in
MINGW*|MSYS*)
	;;
*)
	echo "Expected MSYS2/MinGW environment (uname: $(uname -s 2>/dev/null))" >&2
	echo "See doc/build-environments.md" >&2
	exit 1
	;;
esac

command -v gcc >/dev/null 2>&1 || {
	echo "gcc not on PATH — open MSYS2 UCRT64/MINGW64 shell and install toolchain." >&2
	exit 1
}
command -v make >/dev/null 2>&1 || {
	echo "GNU make not on PATH." >&2
	exit 1
}

LUA_VER="${LUA_VERSION:-5.4.8}"
export LUA_VERSION="$LUA_VER"

sh sys/windows/fetch.sh lua

mkdir -p dat/locale/ko
if command -v msgfmt >/dev/null 2>&1; then
	msgfmt -o dat/locale/ko/nethack.mo po/ko_manual.po
else
	echo "WARNING: msgfmt not found — install gettext; build may fail if .mo missing." >&2
fi

rm -f src/GNUmakefile
cp -f sys/windows/GNUmakefile src/GNUmakefile.win
cp -f sys/windows/GNUmakefile.depend src/GNUmakefile.depend

cd src
make -f GNUmakefile.win GIT=1 clean
make -f GNUmakefile.win GIT=1 depend
make -f GNUmakefile.win GIT=1 package

echo "Done: see ../binary and ../package (MinGW package)."
