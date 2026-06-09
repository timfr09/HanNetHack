#!/bin/sh
# Build makedefs-processed epitaph/engrave/bogusmon for dat/locale/ko/.
# get_rnd_text() expects the padded binary-ish format, not plain .txt.
#
# Usage (from repo root):
#   sh scripts/build-locale-rnddata.sh

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DAT="$ROOT/dat"
KO="$DAT/locale/ko"
MAKEDEFS="$ROOT/util/makedefs"

build_rnd() {
    name=$1
    opt=$2
    src="$KO/${name}.txt"
    out="$KO/${name}"

    if [ ! -f "$src" ]; then
        echo "build-locale-rnddata: skip missing $src" >&2
        return 0
    fi
    if [ -f "$out" ] && [ "$out" -nt "$src" ]; then
        return 0
    fi

    if [ ! -x "$MAKEDEFS" ]; then
        ( cd "$ROOT/util" && make makedefs )
    fi

    saved_txt=""
    if [ -f "$DAT/${name}.txt" ]; then
        cp "$DAT/${name}.txt" "$DAT/${name}.txt.__saved__"
        saved_txt=1
    fi
    saved_bin=""
    if [ -f "$DAT/${name}" ]; then
        cp "$DAT/${name}" "$DAT/${name}.__saved__"
        saved_bin=1
    fi
    cp "$src" "$DAT/${name}.txt"
    ( cd "$DAT" && "$MAKEDEFS" -"$opt" )
    cp "$DAT/$name" "$out"
    rm -f "$DAT/$name"
    if [ -n "$saved_bin" ]; then
        mv "$DAT/${name}.__saved__" "$DAT/${name}"
    fi
    if [ -n "$saved_txt" ]; then
        mv "$DAT/${name}.txt.__saved__" "$DAT/${name}.txt"
    else
        rm -f "$DAT/${name}.txt"
    fi
    echo "build-locale-rnddata: $out"
}

build_rnd epitaph 1
build_rnd engrave 2
build_rnd bogusmon 3
