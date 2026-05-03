#!/bin/bash
# ko_manual.po 안의 obsolete(#~) 항목을 활성 번역으로 병합한다.
# 동일 msgid가 이미 있으면 기존 활성 번역이 우선(msgcat --use-first).
#
# obsolete가 없으면 활성 부분만 유지한다. gettext Win 일부 빌드에서
# msgattrib --obsolete -o 가 빈 출력일 때 파일을 만들지 않아,
# obsolete 스트림은 리다이렉트로 받는다.
#
# 사용: cd po && sh reactivate-obsolete.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PO="$ROOT/ko_manual.po"
ACTIVE="$ROOT/.ko_active.$$"
OBS="$ROOT/.ko_obsolete.$$"

cp -a "$PO" "$PO.bak"
msgattrib --no-obsolete "$PO" -o "$ACTIVE"
msgattrib --obsolete "$PO" > "$OBS"
msgcat --use-first "$ACTIVE" "$OBS" -o "$PO"
rm -f "$ACTIVE" "$OBS"
msgfmt -c -o /dev/null "$PO"
echo "OK: $PO updated (backup: $PO.bak). msgfmt -c passed."
