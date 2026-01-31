#!/bin/bash
# restore-i18n-wrapping.sh
# 업스트림 머지 후 _() 래핑을 자동으로 복구하는 스크립트
#
# 사용법:
#   ./scripts/restore-i18n-wrapping.sh [--dry-run] [--verbose]
#
# 옵션:
#   --dry-run   실제 수정하지 않고 변경될 내용만 표시
#   --verbose   상세 출력

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

DRY_RUN=false
VERBOSE=false

# 파싱 옵션
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
    esac
done

log() {
    if $VERBOSE; then
        echo "$@"
    fi
}

info() {
    echo "[INFO] $@"
}

warn() {
    echo "[WARN] $@" >&2
}

# 변경 카운터
CHANGES=0

# sed 명령 실행 (dry-run 지원)
apply_sed() {
    local pattern="$1"
    local file="$2"

    if $DRY_RUN; then
        # 변경될 내용 미리보기
        local matches=$(grep -c "$pattern" "$file" 2>/dev/null || echo "0")
        if [ "$matches" -gt 0 ]; then
            log "  Would change $matches occurrence(s) in $(basename $file)"
            CHANGES=$((CHANGES + matches))
        fi
    else
        # 실제 적용
        sed -i -E "$pattern" "$file"
    fi
}

# ============================================================
# 1. 메시지 출력 함수들의 문자열 래핑
# ============================================================

wrap_message_functions() {
    info "Wrapping message function strings..."

    # 래핑이 필요한 함수 목록 (플레이어에게 표시되는 메시지)
    # 디버그/내부용 함수는 제외: panic(), impossible(), raw_printf()
    local functions=(
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

    for file in "$SRC_DIR"/*.c; do
        [ -f "$file" ] || continue
        log "Processing $(basename $file)..."

        for func in "${functions[@]}"; do
            # 패턴: func("string") -> func(_("string"))
            # 제외 케이스:
            #   - 이미 _()가 있는 경우
            #   - "%s" 만 있는 경우 (변수 전달)
            #   - "%d", "%ld", "%u" 만 있는 경우 (숫자만)

            # 1. 먼저 이미 래핑된 것들은 건너뜀 (sed는 greedy하므로 괜찮음)
            # 2. 간단한 문자열만 래핑 (복잡한 케이스는 수동)

            # 주의: sed -E에서 \( \)는 그룹, ( )는 리터럴
            # func("text") -> func(_("text"))
            # 단, func("%s", ...) 같은 것은 제외하기 어려우므로
            # 일단 전체 적용 후 수동 검토

            apply_sed "s/${func}\\(\"([^\"]+)\"\\)/${func}(_(\"\\1\"))/g" "$file"
        done
    done
}

# ============================================================
# 2. getlin() 프롬프트 래핑
# ============================================================

wrap_getlin() {
    info "Wrapping getlin() prompts..."

    for file in "$SRC_DIR"/*.c; do
        [ -f "$file" ] || continue

        # getlin("prompt", buf) -> getlin(_("prompt"), buf)
        apply_sed 's/getlin\("([^"]+)",/getlin(_("\1"),/g' "$file"
    done
}

# ============================================================
# 3. Tobjnam() 동사 래핑
# ============================================================

wrap_tobjnam() {
    info "Wrapping Tobjnam() verbs..."

    for file in "$SRC_DIR"/*.c; do
        [ -f "$file" ] || continue

        # Tobjnam(obj, "verb") -> Tobjnam(obj, _("verb"))
        apply_sed 's/Tobjnam\(([^,]+), "([^"]+)"\)/Tobjnam(\1, _("\2"))/g' "$file"
    done
}

# ============================================================
# 4. role.c 특수 처리 - 종족/성별/성향 N_() 래핑
# ============================================================

wrap_role_data() {
    info "Wrapping role.c data structures..."

    local role_file="$SRC_DIR/role.c"
    [ -f "$role_file" ] || return

    # races[] 배열의 문자열 래핑
    # "human" -> N_("human")
    # 단, 이미 N_()가 있으면 건너뜀

    # 종족명
    for race in "human" "elf" "dwarf" "gnome" "orc"; do
        apply_sed "s/\"${race}\"/N_(\"${race}\")/g" "$role_file"
    done

    # 형용사형
    for adj in "elven" "dwarven" "gnomish" "orcish"; do
        apply_sed "s/\"${adj}\"/N_(\"${adj}\")/g" "$role_file"
    done

    # 집합명사
    for kind in "humanity" "elvenkind" "dwarvenkind" "gnomehood" "orcdom"; do
        apply_sed "s/\"${kind}\"/N_(\"${kind}\")/g" "$role_file"
    done

    # 성별
    for gender in "male" "female" "neuter" "group"; do
        apply_sed "s/\"${gender}\"/N_(\"${gender}\")/g" "$role_file"
    done

    # 대명사
    for pronoun in "he" "she" "it" "they" "him" "her" "them" "his" "its" "their"; do
        apply_sed "s/\"${pronoun}\"/N_(\"${pronoun}\")/g" "$role_file"
    done

    # 성향
    for align in "law" "lawful" "balance" "neutral" "chaos" "chaotic" "evil" "unaligned"; do
        apply_sed "s/\"${align}\"/N_(\"${align}\")/g" "$role_file"
    done
}

# ============================================================
# 5. 중복 래핑 제거 (안전장치)
# ============================================================

fix_double_wrapping() {
    info "Fixing double wrapping..."

    for file in "$SRC_DIR"/*.c; do
        [ -f "$file" ] || continue

        # _(_("...")) -> _("...")
        apply_sed 's/_\(_\("([^"]+)"\)\)/_("\1")/g' "$file"

        # N_(N_("...")) -> N_("...")
        apply_sed 's/N_\(N_\("([^"]+)"\)\)/N_("\1")/g' "$file"
    done
}

# ============================================================
# 메인 실행
# ============================================================

main() {
    info "=== HanNetHack i18n Wrapping Restore Script ==="
    info "Project root: $PROJECT_ROOT"

    if $DRY_RUN; then
        info "Running in DRY-RUN mode (no changes will be made)"
    fi

    # 1단계: 메시지 함수 래핑
    wrap_message_functions

    # 2단계: getlin 래핑
    wrap_getlin

    # 3단계: Tobjnam 래핑
    wrap_tobjnam

    # 4단계: role.c 데이터 래핑
    wrap_role_data

    # 5단계: 중복 래핑 수정
    fix_double_wrapping

    info "=== Complete ==="

    if $DRY_RUN; then
        info "Total potential changes: $CHANGES"
        info "Run without --dry-run to apply changes"
    else
        info "Wrapping restored. Please review changes with 'git diff'"
    fi
}

main
