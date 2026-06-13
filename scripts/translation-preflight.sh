#!/usr/bin/env bash
# translation-preflight.sh — PR 전에 gettext + 래핑 + locale dat 점검
#
# 사용: 저장소 루트에서
#   ./scripts/translation-preflight.sh
#
# gettext 도구(msgfmt)가 PATH에 있어야 한다. (MSYS2, Linux, Homebrew 등)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/po"
make translation-ci
cd "$ROOT"
bash scripts/check-i18n-wrapping.sh
echo ""
bash scripts/check-locale-dat-sync.sh
