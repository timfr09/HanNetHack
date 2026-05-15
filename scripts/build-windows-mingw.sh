#!/bin/sh
# Windows MinGW-w64 full build (GNU make + gcc). Typical shell: MSYS2 UCRT64 or MINGW64.
#
# Cross-compiling 문서 Part B와 달리, 여기서는 HOST=TARGET 인 Windows 네이티브 빌드입니다.
#
# Prerequisites (MSYS2 예시):
#   pacman -S mingw-w64-ucrt-x86_64-gcc git make curl tar gettext
#
# Usage (from repo root, inside MSYS2 MinGW shell):
#   sh scripts/build-windows-mingw.sh
#
# HanNetHack: src/GNUmakefile 이름만 있으면 Linux/WSL에서 Unix make가 깨지므로,
# 본 스크립트는 sys/windows/GNUmakefile 을 src/GNUmakefile.win 으로 두고
# `make -f GNUmakefile.win` 으로 빌드합니다. GNUmakefile.depend 은 include 경로상
# src/GNUmakefile.depend 이어야 합니다.

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

# Lua (fetch.sh fixes: correct path guard in repo)
sh sys/windows/fetch.sh lua

# Korean .mo inside nhdat (GNUmakefile 경로에서도 필요)
mkdir -p dat/locale/ko
if command -v msgfmt >/dev/null 2>&1; then
	msgfmt -o dat/locale/ko/nethack.mo po/ko_manual.po
else
	echo "WARNING: msgfmt not found — install gettext; build may fail if .mo missing." >&2
fi

# Sidecar 이름: Unix top-level make는 GNUmakefile을 자동 선택하지 않도록 비우거나 .win만 둠
rm -f src/GNUmakefile
cp -f sys/windows/GNUmakefile src/GNUmakefile.win
cp -f sys/windows/GNUmakefile.depend src/GNUmakefile.depend

cd src
make -f GNUmakefile.win GIT=1 clean
make -f GNUmakefile.win GIT=1 depend
make -f GNUmakefile.win GIT=1 package

echo "Done: see ../binary and ../package (MinGW package)."
