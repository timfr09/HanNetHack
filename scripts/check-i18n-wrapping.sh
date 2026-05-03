#!/bin/bash
# check-i18n-wrapping.sh
# _() 래핑이 누락된 문자열을 검사하는 스크립트
#
# 사용법:
#   ./scripts/check-i18n-wrapping.sh [file...]
#
# 파일을 지정하지 않으면 src/*.c 전체 검사

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

# 색상
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# 검사할 함수 목록 (플레이어에게 표시되는 메시지만)
MESSAGE_FUNCTIONS=(
    "pline"
    "You"
    "Your"
    "You_feel"
    "You_hear"
    "You_see"
    "You_cant"
    "pline_The"
    "There"
    "Norep"
    "verbalize"
    "selftouch"
)
# getlin 은 아래 check_file 에서 tty_getlin / hooked_tty_getlin 만 검사
# msmsg 는 제어·순수 포맷 호출을 제외하고 별도 검사
# 추가 디렉터리 (기본은 src/*.c 만): win 포트, Unix/VMS/sys 공유 코드
EXTRA_CHECK_DIRS=(
    "$PROJECT_ROOT/win/tty"
    "$PROJECT_ROOT/win/curses"
    "$PROJECT_ROOT/win/win32"
    "$PROJECT_ROOT/sys/unix"
    "$PROJECT_ROOT/sys/share"
    "$PROJECT_ROOT/sys/vms"
)

# 디버그/내부용 함수 (번역 불필요)
# - impossible(): 내부 오류 메시지
# - panic(): 치명적 오류 메시지
# - raw_printf(): 디버그 출력

ISSUES_FOUND=0

check_file() {
    local file="$1"
    local file_issues=0

    for func in "${MESSAGE_FUNCTIONS[@]}"; do
        # 패턴: func("string" - _()가 없는 경우
        # 제외:
        #   - func(_(" 또는 func(N_(" 또는 func(C_(" - 이미 래핑됨
        #   - func("%s" - 변수 전달만 하는 경우
        #   - func("%d" - 숫자만 출력
        # 블록 주석 줄(/* ...)은 오탐이 많음 — 줄 시작이 공백+/* 인 매치 제외
        local matches=$(grep -n "${func}(\"" "$file" 2>/dev/null \
            | grep -v "${func}(_(" \
            | grep -v "${func}(N_(" \
            | grep -v "${func}(C_(" \
            | grep -v "${func}(\"%s\"" \
            | grep -v "${func}(\"%d\"" \
            | grep -v "${func}(\"%ld\"" \
            | grep -v "${func}(\"%u\"" \
            | grep -vE '^[^:]+:[[:space:]]*/\*' \
            || true)

        if [ -n "$matches" ]; then
            if [ $file_issues -eq 0 ]; then
                echo -e "${YELLOW}=== $(basename $file) ===${NC}"
            fi
            file_issues=$((file_issues + 1))

            while IFS= read -r line; do
                local linenum=$(echo "$line" | cut -d: -f1)
                local content=$(echo "$line" | cut -d: -f2-)
                echo -e "  ${RED}Line $linenum:${NC} $func() missing _()"
                echo "    $content"
            done <<< "$matches"
        fi
    done

    # tty_getlin / hooked_tty_getlin — 접두 getlin(" 오탐(hooked_tty_getlin) 방지
    local gl_matches=$(grep -nE '(tty_getlin|hooked_tty_getlin)\("' "$file" 2>/dev/null \
        | grep -vE '(tty_getlin|hooked_tty_getlin)\(_\("' \
        | grep -vE '(tty_getlin|hooked_tty_getlin)\(N_\("' \
        | grep -vE '(tty_getlin|hooked_tty_getlin)\(C_\("' \
        | grep -vE '^[^:]+:[[:space:]]*\*' \
        | grep -vE '^[^:]+:[[:space:]]*/\*' \
        || true)
    if [ -n "$gl_matches" ]; then
        if [ $file_issues -eq 0 ]; then
            echo -e "${YELLOW}=== $(basename $file) ===${NC}"
        fi
        file_issues=$((file_issues + 1))
        while IFS= read -r line; do
            local linenum=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)
            echo -e "  ${RED}Line $linenum:${NC} tty_getlin/hooked_tty_getlin missing _()"
            echo "    $content"
        done <<< "$gl_matches"
    fi

    # msmsg — 제어 문자·순수 포맷만 넘기는 호출은 번역 불필요
    local msm_matches=$(grep -n 'msmsg("' "$file" 2>/dev/null \
        | grep -v 'msmsg(_("' \
        | grep -v 'msmsg(N_("' \
        | grep -v 'msmsg(C_("' \
        | grep -v 'msmsg("%s"' \
        | grep -v 'msmsg("%s\\n"' \
        | grep -v 'msmsg("%c"' \
        | grep -v 'msmsg("\\n"' \
        | grep -v 'msmsg("\\b \\b")' \
        | grep -vE '^[^:]+:[[:space:]]*/\*' \
        || true)
    if [ -n "$msm_matches" ]; then
        if [ $file_issues -eq 0 ]; then
            echo -e "${YELLOW}=== $(basename $file) ===${NC}"
        fi
        file_issues=$((file_issues + 1))
        while IFS= read -r line; do
            local linenum=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)
            echo -e "  ${RED}Line $linenum:${NC} msmsg() missing _()"
            echo "    $content"
        done <<< "$msm_matches"
    fi

    # Tobjnam 체크
    local tobjnam_matches=$(grep -n 'Tobjnam([^,]*, "' "$file" 2>/dev/null | grep -v 'Tobjnam([^,]*, _(' || true)
    if [ -n "$tobjnam_matches" ]; then
        if [ $file_issues -eq 0 ]; then
            echo -e "${YELLOW}=== $(basename $file) ===${NC}"
        fi
        file_issues=$((file_issues + 1))

        while IFS= read -r line; do
            local linenum=$(echo "$line" | cut -d: -f1)
            echo -e "  ${RED}Line $linenum:${NC} Tobjnam() verb missing _()"
        done <<< "$tobjnam_matches"
    fi

    ISSUES_FOUND=$((ISSUES_FOUND + file_issues))
}

check_role_data() {
    local role_file="$SRC_DIR/role.c"
    [ -f "$role_file" ] || return

    echo -e "${YELLOW}=== Checking role.c data structures ===${NC}"

    # races[] 체크 - N_() 없이 사용된 문자열
    local race_issues=0

    # 종족명/형용사 체크
    for word in "human" "elf" "dwarf" "gnome" "orc" "elven" "dwarven" "gnomish" "orcish" \
                "humanity" "elvenkind" "dwarvenkind" "gnomehood" "orcdom" \
                "male" "female" "neuter" "group" \
                "he" "she" "it" "they" "him" "her" "them" "his" "its" "their" \
                "law" "lawful" "balance" "neutral" "chaos" "chaotic" "evil" "unaligned"; do
        # "word" 패턴 (N_() 없이)
        local matches=$(grep -n "\"${word}\"" "$role_file" 2>/dev/null | grep -v "N_(\"${word}\")" || true)
        if [ -n "$matches" ]; then
            race_issues=$((race_issues + 1))
            while IFS= read -r line; do
                local linenum=$(echo "$line" | cut -d: -f1)
                echo -e "  ${RED}Line $linenum:${NC} \"$word\" missing N_()"
            done <<< "$matches"
        fi
    done

    if [ $race_issues -eq 0 ]; then
        echo -e "  ${GREEN}All data structures properly wrapped${NC}"
    fi

    ISSUES_FOUND=$((ISSUES_FOUND + race_issues))
}

main() {
    echo "=== HanNetHack i18n Wrapping Check ==="
    echo ""

    if [ $# -gt 0 ]; then
        # 지정된 파일만 검사
        for file in "$@"; do
            if [ -f "$file" ]; then
                check_file "$file"
            else
                echo "File not found: $file"
            fi
        done
    else
        # src/*.c 전체 검사
        for file in "$SRC_DIR"/*.c; do
            [ -f "$file" ] || continue
            check_file "$file"
        done

        # win/sys 포트 및 공유 코드
        for dir in "${EXTRA_CHECK_DIRS[@]}"; do
            [ -d "$dir" ] || continue
            for file in "$dir"/*.c; do
                [ -f "$file" ] || continue
                check_file "$file"
            done
        done

        # role.c 데이터 구조 검사
        echo ""
        check_role_data
    fi

    echo ""
    echo "=== Summary ==="
    if [ $ISSUES_FOUND -eq 0 ]; then
        echo -e "${GREEN}No i18n wrapping issues found!${NC}"
    else
        echo -e "${RED}Found $ISSUES_FOUND potential issues${NC}"
        echo "Run ./scripts/restore-i18n-wrapping.sh to fix automatically"
    fi

    exit $ISSUES_FOUND
}

main "$@"
