#!/usr/bin/env bash
# dat/*.lua (영어 원본)와 dat/locale/ko/*.lua 짝이 맞는지 빠르게 점검한다.
# 영어 쪽이 업스트림에서 크게 바뀌었을 때 한국어 파일을 재검토·병합할 때 사용.
#
# 사용: ./scripts/check-locale-lua-sync.sh
#
# 번역 워크플로 (요약):
#   1) git diff <upstream> -- dat/nhlib.lua   등으로 원본 변경 확인
#   2) 동일 파일명으로 dat/locale/ko/ 에서 열어, 맵·오브젝트·로직 변경을 영어와
#      동일하게 맞춘 뒤, nh.pline / des.message / 퀘스트 text 블록만 한국어로 유지

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KO_DIR="$ROOT/dat/locale/ko"
# 줄 수 차이가 이 값을 넘으면 수동 병합 점검 권고 (번역만 다른 경우도 있음)
LINE_DELTA_WARN="${LINE_DELTA_WARN:-25}"

echo "=== HanNetHack dat/locale/ko Lua 동기화 점검 ==="
echo ""

issues=0
shopt -s nullglob
for ko in "$KO_DIR"/*.lua; do
    base="$(basename "$ko")"
    eng="$ROOT/dat/$base"
    if [ ! -f "$eng" ]; then
        echo "[WARN] 영어 원본 없음: dat/locale/ko/$base"
        issues=$((issues + 1))
        continue
    fi
    le=$(wc -l <"$eng" | tr -d ' \r')
    lk=$(wc -l <"$ko" | tr -d ' \r')
    if [ "$lk" -ge "$le" ]; then
        d=$((lk - le))
    else
        d=$((le - lk))
    fi

    # 메시지/API 관련 줄 개수 (전부는 아님; quest.lua 는 output= / text = [[ ]] 등 혼합)
    api_pat='nh\.(pline|text|verbalize)|des\.message|output[[:space:]]*=[[:space:]]*"(pline|text|menu)"'
    ce=$(grep -cE "$api_pat" "$eng" 2>/dev/null || echo 0)
    ck=$(grep -cE "$api_pat" "$ko" 2>/dev/null || echo 0)

    note="OK"
    if [ "$ce" != "$ck" ]; then
        note="CHECK api_lines eng=$ce ko=$ck"
        issues=$((issues + 1))
    fi
    if [ "$d" -gt "$LINE_DELTA_WARN" ]; then
        note="CHECK line_Δ=${d} (${note})"
        issues=$((issues + 1))
    fi

    printf "  %-14s  lines %4s / %-4s (Δ%3s)  %s\n" "$base" "$le" "$lk" "$d" "$note"
done

echo ""
echo "CHECK 이면: 원본 대비 한국어 파일이 오래됐을 수 있음 → diff로 확인 후 병합."
echo "  예: diff -u dat/nhlib.lua dat/locale/ko/nhlib.lua | less"
echo "  줄 수만으로는 로직/메시지 누락이 안 보일 수 있음 → 심층 점검:"
echo "  python3 scripts/audit-locale-lua-structure.py"
echo ""

if [ "$issues" -gt 0 ]; then
    echo "점검 항목이 $issues 건 있습니다 (위 CHECK/WARN)."
else
    echo "줄 수·API 패턴 기준으로는 특이 차이 없음 (번역 문구 차이는 정상)."
fi
