#!/bin/sh
set -eu

# Optional third-party archives for Windows helpers (PDCursesMod).
# Lua is vendored under nhlua/ (no fetch-lua). Typical:
#   `sh sys/windows/fetch.sh pdcursesmod` from repository root.

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
*)
	echo "usage: $0 pdcursesmod" >&2
	exit 1
	;;
esac
