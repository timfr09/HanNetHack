#!/usr/bin/env bash
# check-locale-dat-sync.sh
# dat/help·TXT(영어)와 dat/locale/ko/ 짝의 동기화 상태를 점검한다.
#
# 자동 번역은 하지 않는다. 업스트림 머지·dat/ 변경 후 "어디를 손봐야 하는지"
# 목록을 내는 도구다.
#
# 사용:
#   ./scripts/check-locale-dat-sync.sh          # 경고 포함, exit 0 (정보 출력)
#   ./scripts/check-locale-dat-sync.sh --strict # HARD 이슈 있으면 exit 1
#
# 관련: scripts/check-locale-lua-sync.sh (Lua 전용)
#       scripts/report-locale-ko-coverage.py (영어 잔존 휴리스틱)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DAT="$ROOT/dat"
KO="$DAT/locale/ko"

STRICT=0
if [ "${1:-}" = "--strict" ]; then
    STRICT=1
fi

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# help / TXT — PO 밖 locale 교체 파일 (doc/i18n-upstream-merge.md §3)
LOCALE_TXT=(
    help hh cmdhelp keyhelp opthelp optmenu usagehlp wizhelp history
    bogusmon.txt engrave.txt epitaph.txt oracles.txt rumors.tru rumors.fal
)

HARD=0
SOFT=0

note_hard() {
    HARD=$((HARD + 1))
    echo -e "  ${RED}HARD${NC} $*"
}

note_soft() {
    SOFT=$((SOFT + 1))
    echo -e "  ${YELLOW}SOFT${NC} $*"
}

note_ok() {
    echo -e "  ${GREEN}OK${NC}   $*"
}

# opthelp / optmenu: option definition lines (name + … + [default])
extract_opt_keys() {
    awk '/^[a-z][a-z_0-9]*[[:space:]]+/ && /\[[^]]+\][[:space:]]*$/ { print $1 }' "$1" | sort -u
}

# cmdhelp: conditional block markers
count_cmdhelp_markers() {
    local f="$1" kind="$2"
    grep -cE "^&[${kind}]" "$f" 2>/dev/null || echo 0
}

# oracles.txt: ----- blocks
count_oracle_blocks() {
    grep -c '^-----$' "$1" 2>/dev/null || echo 0
}

# rumors / bogusmon / engrave / epitaph: non-empty content lines
count_nonempty_lines() {
    grep -cE '.+' "$1" 2>/dev/null || echo 0
}

git_last_touch() {
    git -C "$ROOT" log -1 --format=%ct -- "$1" 2>/dev/null || echo 0
}

echo "=== HanNetHack dat/locale/ko TXT·도움말 동기화 점검 ==="
echo ""

for base in "${LOCALE_TXT[@]}"; do
    en="$DAT/$base"
    kr="$KO/$base"
    echo "[$base]"

    if [ ! -f "$en" ]; then
        note_soft "영어 원본 없음: dat/$base"
        echo ""
        continue
    fi
    if [ ! -f "$kr" ]; then
        note_hard "한국어 사본 없음: dat/locale/ko/$base"
        echo ""
        continue
    fi

    le=$(wc -l <"$en" | tr -d ' \r')
    lk=$(wc -l <"$kr" | tr -d ' \r')
    if [ "$lk" -ge "$le" ]; then
        ld=$((lk - le))
    else
        ld=$((le - lk))
    fi

    en_t=$(git_last_touch "dat/$base")
    ko_t=$(git_last_touch "dat/locale/ko/$base")
    if [ "$en_t" -gt "$ko_t" ] && [ "$en_t" -gt 0 ] && [ "$ko_t" -gt 0 ]; then
        note_soft "영어가 더 최근 (EN $(git -C "$ROOT" log -1 --format=%cs -- "dat/$base") > KO $(git -C "$ROOT" log -1 --format=%cs -- "dat/locale/ko/$base"))"
    fi

    case "$base" in
        opthelp|optmenu)
            mapfile -t missing < <(comm -23 \
                <(extract_opt_keys "$en") \
                <(extract_opt_keys "$kr"))
            if [ "${#missing[@]}" -gt 0 ]; then
                note_hard "옵션 키 ${#missing[@]}개 KO 누락: ${missing[*]}"
            else
                note_ok "옵션 키 집합 일치 (${le}/${lk} lines, Δ${ld})"
            fi
            ;;
        cmdhelp)
            cmd_ok=1
            for m in '? : .'; do
                ce=$(count_cmdhelp_markers "$en" "$m")
                ck=$(count_cmdhelp_markers "$kr" "$m")
                if [ "$ce" != "$ck" ]; then
                    note_hard "조건 지시자 &$m 개수 불일치 EN=$ce KO=$ck"
                    cmd_ok=0
                fi
            done
            if [ "$ld" -gt 15 ]; then
                note_soft "줄 수 차이 큼 EN=$le KO=$lk (Δ${ld})"
            elif [ "$cmd_ok" -eq 1 ]; then
                note_ok "조건 블록·줄 수 (${le}/${lk}, Δ${ld})"
            fi
            ;;
        oracles.txt)
            be=$(count_oracle_blocks "$en")
            bk=$(count_oracle_blocks "$kr")
            if [ "$be" != "$bk" ]; then
                note_hard "신탁 블록(-----) EN=$be KO=$bk"
            elif [ "$ld" -gt 10 ]; then
                note_soft "줄 수 Δ${ld} (블록 수는 같음)"
            else
                note_ok "신탁 블록 ${be}개 (${le}/${lk} lines)"
            fi
            ;;
        history)
            if head -n 3 "$en" | grep -q 'release 5\.0' \
                && ! head -n 3 "$kr" | grep -qE 'release 5\.0|5\.0\.0|5\.0 릴리스'; then
                note_hard "KO 헤더가 5.0 동기화 전 (EN: release 5.0)"
            fi
            if [ "$ld" -gt 40 ]; then
                note_soft "줄 수 차이 큼 EN=$le KO=$lk (Δ${ld}) — 문단 누락 가능"
            elif [ "$ld" -le 40 ]; then
                note_ok "history (${le}/${lk} lines, Δ${ld})"
            fi
            ;;
        rumors.tru|rumors.fal|bogusmon.txt|engrave.txt|epitaph.txt)
            ne=$(count_nonempty_lines "$en")
            nk=$(count_nonempty_lines "$kr")
            if [ "$ne" != "$nk" ]; then
                note_soft "비어 있지 않은 줄 EN=$ne KO=$nk (번역 압축/누락 점검)"
            else
                note_ok "항목 줄 수 ${ne} (${le}/${lk} lines)"
            fi
            ;;
        *)
            # help, hh, usagehlp, wizhelp, keyhelp — 구조가 느슨하므로 줄 수·최신성만
            thresh=20
            [ "$base" = "help" ] && thresh=25
            [ "$base" = "hh" ] && thresh=15
            if [ "$ld" -gt "$thresh" ]; then
                note_soft "줄 Δ${ld} > ${thresh} (EN=$le KO=$lk) — diff 후 문단 단위 반영 권장"
            else
                note_ok "줄 수 (${le}/${lk}, Δ${ld})"
            fi
            ;;
    esac
    echo ""
done

echo "=== 요약 ==="
echo "HARD(반드시 손볼 것): $HARD"
echo "SOFT(검토 권장):      $SOFT"
echo ""
echo "다음 단계 (수동 동기화):"
echo "  1) git diff upstream/NetHack-5.0 -- dat/help dat/opthelp dat/history …"
echo "  2) diff -u dat/opthelp dat/locale/ko/opthelp | less"
echo "  3) 영어 변경분을 **문단/옵션/항목 단위**로 번역해 KO에 반영 (줄 1:1 금지)"
echo "  4) 게임 ? 메뉴에서 해당 도움말 확인"
echo "  5) Lua: ./scripts/check-locale-lua-sync.sh"
echo "  6) 영어 잔존 휴리스틱: python3 scripts/report-locale-ko-coverage.py"
echo ""

if [ "$STRICT" -eq 1 ] && [ "$HARD" -gt 0 ]; then
    exit 1
fi
exit 0
