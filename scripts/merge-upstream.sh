#!/bin/bash
# merge-upstream.sh
# 업스트림 변경사항을 안전하게 머지하는 스크립트
#
# 사용법:
#   ./scripts/merge-upstream.sh [upstream-branch]
#
# 기본값: upstream/NetHack-5.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $@"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $@"
}

error() {
    echo -e "${RED}[ERROR]${NC} $@" >&2
}

# Git rerere 활성화 확인
ensure_rerere() {
    local rerere_enabled=$(git config --get rerere.enabled 2>/dev/null || echo "false")
    if [ "$rerere_enabled" != "true" ]; then
        info "Enabling git rerere for automatic conflict resolution memory..."
        git config rerere.enabled true
    fi
}

# 업스트림 브랜치 결정
get_upstream_branch() {
    local branch="${1:-}"

    if [ -n "$branch" ]; then
        echo "$branch"
        return
    fi

    # HanNetHack-5.0 tracks upstream NetHack-5.0
    if git remote | grep -q "^upstream$"; then
        echo "upstream/NetHack-5.0"
    else
        echo "origin/HanNetHack-5.0"
    fi
}

# 작업 디렉토리 상태 확인
check_working_directory() {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        error "Working directory has uncommitted changes. Please commit or stash first."
        exit 1
    fi
}

# 머지 수행
do_merge() {
    local upstream="$1"

    info "Fetching from remote..."
    git fetch --all

    info "Attempting merge from $upstream..."

    # 머지 시도
    if git merge "$upstream" --no-edit; then
        info "Merge completed successfully!"
        return 0
    else
        warn "Merge has conflicts. Attempting automatic resolution..."
        return 1
    fi
}

# 충돌 시 중단 + 수동 리뷰 힌트 (절대 --theirs로 로컬 i18n 로직을 버리지 않음)
abort_on_conflicts() {
    local conflicted_files
    conflicted_files=$(git diff --name-only --diff-filter=U || true)

    if [ -z "$conflicted_files" ]; then
        return 0
    fi

    error "Merge conflicts require manual resolution (no auto --theirs)."
    echo "$conflicted_files"
    echo ""
    info "Files that also touch Korean/i18n helpers (review carefully):"
    # shellcheck disable=SC2086
    for file in $conflicted_files; do
        if [ -f "$file" ] && grep -Eq 'is_korean_locale|ko_process_string|KO_PP_|nh_gettext|\(\_|C_\(|N_\(' "$file" 2>/dev/null; then
            echo "  * $file"
        fi
    done
    echo ""
    echo "Resolve conflicts (keep upstream logic + re-apply _()/C_() and KO paths), then:"
    echo "  git add <resolved-files>"
    echo "  git commit"
    echo "  cd po && make pot && make compile && make untranslated"
    echo "See doc/i18n-upstream-merge.md"
    exit 1
}

# i18n 래핑 복구
restore_wrapping() {
    info "Restoring i18n wrapping..."

    if [ -x "$SCRIPT_DIR/restore-i18n-wrapping.sh" ]; then
        "$SCRIPT_DIR/restore-i18n-wrapping.sh"
    else
        warn "restore-i18n-wrapping.sh not found or not executable"
    fi
}

# 번역 파일 업데이트
update_translations() {
    info "Updating translation files..."

    local po_dir="$PROJECT_ROOT/po"
    if [ -d "$po_dir" ] && [ -f "$po_dir/Makefile" ]; then
        cd "$po_dir"
        make pot 2>/dev/null || warn "Failed to regenerate POT file"
        make compile 2>/dev/null || warn "Failed to compile translations"
        cd "$PROJECT_ROOT"
    fi
}

# 빌드 테스트
test_build() {
    info "Testing build..."

    cd "$PROJECT_ROOT"
    # Lua is in-tree under nhlua/; parallel make is not recommended
    if make all; then
        info "Build successful!"
    else
        error "Build failed. Please check errors."
        exit 1
    fi
}

# 메인
main() {
    cd "$PROJECT_ROOT"

    local upstream=$(get_upstream_branch "$1")

    info "=== HanNetHack Upstream Merge Script ==="
    info "Upstream branch: $upstream"
    info ""

    # 사전 체크
    check_working_directory
    ensure_rerere

    # 머지 수행 (충돌 시 abort_on_conflicts로 종료)
    if ! do_merge "$upstream"; then
        abort_on_conflicts
    fi

    # 래핑 복구는 보조 수단일 뿐 — 충돌 없는 자동머지에서만 시도
    restore_wrapping

    if ! git diff --quiet; then
        info "i18n wrapping script changed files; review before committing:"
        git status --short
        warn "Not auto-committing. Stage/commit only after review."
    fi

    # 번역 업데이트 (POT/compile; 실패는 경고만)
    update_translations

    info "Manual review checklist:"
    info "  - git diff upstream...HEAD --stat"
    info "  - cd po && make untranslated / msgcmp ko_manual.po nethack.pot"
    info "  - files with is_korean_locale / ko_process_string after merge"

    # 빌드 테스트
    test_build

    info ""
    info "=== Merge Complete ==="
    info "Please review changes with: git log --oneline -10"
    info "And test the game before pushing."
}

main "$@"
