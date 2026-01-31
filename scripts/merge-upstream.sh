#!/bin/bash
# merge-upstream.sh
# 업스트림 변경사항을 안전하게 머지하는 스크립트
#
# 사용법:
#   ./scripts/merge-upstream.sh [upstream-branch]
#
# 기본값: upstream/master 또는 origin/NetHack-3.7

set -e

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

    # upstream 리모트가 있으면 사용
    if git remote | grep -q "^upstream$"; then
        echo "upstream/master"
    else
        echo "origin/NetHack-3.7"
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

# 충돌 해결 시도
resolve_conflicts() {
    local conflicted_files=$(git diff --name-only --diff-filter=U)

    if [ -z "$conflicted_files" ]; then
        return 0
    fi

    info "Conflicted files:"
    echo "$conflicted_files"

    # i18n 관련 파일 충돌은 업스트림 버전 사용 후 래핑 복구
    for file in $conflicted_files; do
        if [[ "$file" == src/*.c ]]; then
            warn "Taking upstream version for $file (will restore i18n wrapping later)"
            git checkout --theirs "$file"
            git add "$file"
        fi
    done

    # 아직 충돌이 남아있는지 확인
    local remaining=$(git diff --name-only --diff-filter=U)
    if [ -n "$remaining" ]; then
        error "Some conflicts require manual resolution:"
        echo "$remaining"
        echo ""
        echo "Please resolve these conflicts manually, then run:"
        echo "  git add <resolved-files>"
        echo "  git commit"
        echo "  ./scripts/restore-i18n-wrapping.sh"
        exit 1
    fi
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
    if make -j$(nproc) 2>&1 | tail -5; then
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

    # 머지 수행
    if do_merge "$upstream"; then
        # 충돌 없이 성공
        :
    else
        # 충돌 해결 시도
        resolve_conflicts

        # 머지 커밋 완료
        git commit --no-edit || true
    fi

    # i18n 래핑 복구
    restore_wrapping

    # 변경사항 있으면 커밋
    if ! git diff --quiet; then
        info "Committing i18n wrapping restoration..."
        git add -A
        git commit -m "Restore i18n wrapping after upstream merge

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
    fi

    # 번역 업데이트
    update_translations

    # 빌드 테스트
    test_build

    info ""
    info "=== Merge Complete ==="
    info "Please review changes with: git log --oneline -10"
    info "And test the game before pushing."
}

main "$@"
