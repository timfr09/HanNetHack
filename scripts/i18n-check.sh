#!/bin/bash
# 업스트림 병합 후 번역 상태 확인

echo "=== 1. C 소스 새 문자열 확인 ==="
xgettext --keyword=_ --keyword=N_ --language=C \
  --add-comments --sort-output --from-code=UTF-8 \
  -o /tmp/new.pot src/*.c 2>/dev/null

if [ -f po/nethack.pot ]; then
  diff <(grep "^msgid" po/nethack.pot | sort) \
       <(grep "^msgid" /tmp/new.pot | sort) | grep "^>" | head -20
fi

echo ""
echo "=== 2. ko.po 통계 ==="
msgfmt --statistics po/ko.po -o /dev/null 2>&1

echo ""
echo "=== 3. 래핑 안 된 메시지 확인 ==="
grep -rn 'pline("[^_]' src/*.c | grep -v '_("' | head -10
grep -rn 'You("[^_]' src/*.c | grep -v '_("' | head -10

echo ""
echo "=== 4. Lua 파일 메시지 변경 확인 ==="
for f in dat/nhcore.lua dat/nhlib.lua dat/quest.lua; do
  if [ -f "$f" ]; then
    ko_file="dat/locale/ko/$(basename $f)"
    if [ -f "$ko_file" ]; then
      # 메시지 라인만 비교
      en_msg=$(grep -c "pline\|verbalize\|nh.text" "$f" 2>/dev/null || echo 0)
      ko_msg=$(grep -c "pline\|verbalize\|nh.text" "$ko_file" 2>/dev/null || echo 0)
      if [ "$en_msg" != "$ko_msg" ]; then
        echo "메시지 수 다름: $f (EN:$en_msg, KO:$ko_msg)"
      fi
    else
      echo "한국어 파일 없음: $f"
    fi
  fi
done

echo ""
echo "=== 5. 도움말 파일 크기 비교 ==="
for f in help hh cmdhelp keyhelp opthelp; do
  if [ -f "dat/$f" ] && [ -f "dat/locale/ko/$f" ]; then
    en_size=$(wc -l < "dat/$f")
    ko_size=$(wc -l < "dat/locale/ko/$f")
    diff_pct=$((100 * (ko_size - en_size) / en_size))
    if [ $diff_pct -lt -10 ] || [ $diff_pct -gt 50 ]; then
      echo "확인 필요: $f (EN:${en_size}줄, KO:${ko_size}줄, 차이:${diff_pct}%)"
    fi
  fi
done
