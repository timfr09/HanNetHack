#!/bin/sh
# Build makedefs-processed locale/ko data files for nhdat.
# - epitaph/engrave/bogusmon: get_rnd_text() needs the padded format, not .txt
# - data: encyclopedia lookup opens "data" via dlb_fopen → locale/ko/data
#
# Usage (from repo root):
#   sh scripts/build-locale-rnddata.sh
#
# makedefs must keep UTF-8 (do_filtering=FALSE for data/rumors/etc).
# A stale Windows util/makedefs.exe built before that fix turns Hangul into '#'.
# Prefer a current host binary, or WSL's ELF util/makedefs.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DAT="$ROOT/dat"
KO="$DAT/locale/ko"
MAKEDEFS=""

# Convert a Git-Bash/MSYS path to something Windows Python understands.
win_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

hangul_count() {
    f=$1
    py=python3
    command -v python3 >/dev/null 2>&1 || py=python
    "$py" -c "import pathlib,re,sys; t=pathlib.Path(sys.argv[1]).read_text(encoding='utf-8',errors='replace'); print(len(re.findall(r'[\uac00-\ud7a3]', t)))" "$(win_path "$f")"
}

resolve_makedefs() {
    uname_s=$(uname -s 2>/dev/null || echo unknown)

    # Linux / WSL: use ELF util/makedefs (includes UTF-8 data.base fix).
    case "$uname_s" in
    Linux*)
        if [ -x "$ROOT/util/makedefs" ]; then
            MAKEDEFS="$ROOT/util/makedefs"
            return 0
        fi
        if command -v make >/dev/null 2>&1; then
            ( cd "$ROOT/util" && make makedefs )
            MAKEDEFS="$ROOT/util/makedefs"
            return 0
        fi
        ;;
    esac

    # Windows Git Bash / MSYS: prefer WSL ELF over a possibly stale .exe
    # (pre-UTF-8-fix makedefs.exe turns Hangul into '#').
    case "$uname_s" in
    MINGW*|MSYS*|CYGWIN*)
        if command -v wsl >/dev/null 2>&1 && [ -f "$ROOT/util/makedefs" ]; then
            wsl_md=$(wsl -e wslpath -a "$ROOT/util/makedefs" 2>/dev/null || true)
            if [ -n "$wsl_md" ] && wsl -e bash -lc "test -x \"$wsl_md\""; then
                MAKEDEFS="wsl_makedefs:$wsl_md"
                return 0
            fi
        fi
        if [ -x "$ROOT/util/makedefs.exe" ]; then
            MAKEDEFS="$ROOT/util/makedefs.exe"
            return 0
        fi
        ;;
    esac

    echo "build-locale-rnddata: no runnable util/makedefs(.exe)" >&2
    exit 1
}

run_makedefs() {
    case "$MAKEDEFS" in
    wsl_makedefs:*)
        wsl_md=${MAKEDEFS#wsl_makedefs:}
        wsl_dat=$(wsl -e wslpath -a "$DAT")
        # makedefs resolves ../dat from its cwd; run inside the dat dir via WSL.
        wsl -e bash -lc "cd \"$wsl_dat\" && \"$wsl_md\" $(printf '%q ' "$@")"
        ;;
    *)
        ( cd "$DAT" && "$MAKEDEFS" "$@" )
        ;;
    esac
}

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
    run_makedefs -"$opt"
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

# Compile locale/ko/data.base → locale/ko/data (same format as English dat/data).
build_encyclopedia() {
    src="$KO/data.base"
    out="$KO/data"

    if [ ! -f "$src" ]; then
        echo "build-locale-rnddata: skip missing $src" >&2
        return 0
    fi
    if [ -f "$out" ] && [ "$out" -nt "$src" ]; then
        n=$(hangul_count "$out" || echo 0)
        if [ "$n" -gt 1000 ]; then
            return 0
        fi
        echo "build-locale-rnddata: rebuilding $out (Hangul=$n; stale makedefs?)" >&2
        rm -f "$out"
    fi

    # Unique temps + trap so a crash cannot leave Korean text in dat/data.base.
    saved_base=$(mktemp "${TMPDIR:-/tmp}/nh-data.base.XXXXXX")
    saved_data=$(mktemp "${TMPDIR:-/tmp}/nh-data.XXXXXX")
    have_base=0
    have_data=0
    restore_en() {
        if [ "$have_base" -eq 1 ]; then
            mv -f "$saved_base" "$DAT/data.base"
        else
            rm -f "$saved_base"
        fi
        if [ "$have_data" -eq 1 ]; then
            mv -f "$saved_data" "$DAT/data"
        else
            rm -f "$saved_data" "$DAT/data"
        fi
    }
    trap restore_en EXIT INT TERM

    if [ -f "$DAT/data.base" ]; then
        cp "$DAT/data.base" "$saved_base"
        have_base=1
    fi
    if [ -f "$DAT/data" ]; then
        cp "$DAT/data" "$saved_data"
        have_data=1
    fi
    cp "$src" "$DAT/data.base"
    run_makedefs -d
    cp "$DAT/data" "$out"
    restore_en
    trap - EXIT INT TERM

    n=$(hangul_count "$out" || echo 0)
    echo "build-locale-rnddata: Hangul chars in data: $n"
    if [ "$n" -le 1000 ]; then
        echo "build-locale-rnddata: ERROR $out lost Korean text." >&2
        echo "  Rebuild util/makedefs after the UTF-8 data.base fix, or use WSL." >&2
        rm -f "$out"
        exit 1
    fi
    echo "build-locale-rnddata: $out"
}

resolve_makedefs
echo "build-locale-rnddata: using $MAKEDEFS"
build_rnd epitaph 1
build_rnd engrave 2
build_rnd bogusmon 3
build_encyclopedia
