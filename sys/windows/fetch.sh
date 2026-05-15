#!/bin/sh
set -eu

# Optional third-party archives for Windows helpers (Lua, PDCursesMod).
# Typical: `sh sys/windows/fetch.sh lua` from repository root.

if [ ! -d lib ]; then
	mkdir -p lib
fi

# Prefer bundled Windows tar when present (handles .zip reliably on MSYS2).
_tar() {
	if [ -x /c/Windows/System32/tar.exe ]; then
		/c/Windows/System32/tar.exe "$@"
	else
		tar "$@"
	fi
}

case "${1:-}" in
lua)
	if [ -z "${LUA_VERSION:-}" ]; then
		LUA_VERSION=5.4.8
		export LUA_VERSION
	fi
	export LUASRC=../lib/lua

	CURLLUASRC="http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
	CURLLUADST="lua-${LUA_VERSION}.tar.gz"

	_LUA_TOP="lib/lua-${LUA_VERSION}"
	if [ ! -f "${_LUA_TOP}/src/lua.h" ]; then
		(
			cd lib
			curl -fL "$CURLLUASRC" -o "$CURLLUADST"
			_tar -xvf "$CURLLUADST"
		)
	fi
	;;
pdcursesmod)
	CURLPDCSRC="https://github.com/Bill-Gray/PDCursesMod/archive/refs/tags/v4.4.0.zip"
	CURLPDCDST="pdcursesmod.zip"

	if [ ! -f lib/pdcursesmod/curses.h ]; then
		(
			cd lib
			curl -fL "$CURLPDCSRC" -o "$CURLPDCDST"
			_tar -xvf "$CURLPDCDST"
			mkdir -p pdcursesmod
			_tar -C pdcursesmod --strip-components=1 -xvf "$CURLPDCDST"
		)
	fi
	;;
esac
