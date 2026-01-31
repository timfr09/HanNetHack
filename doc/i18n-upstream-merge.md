# HanNetHack 업스트림 병합 가이드

이 문서는 NetHack 업스트림에서 변경 사항을 가져올 때 한국어 번역을 유지하는 방법을 설명합니다.

## 목차

1. [번역 시스템 개요](#번역-시스템-개요)
2. [파일 유형별 전략](#파일-유형별-전략)
3. [업스트림 병합 절차](#업스트림-병합-절차)
4. [자동화 스크립트](#자동화-스크립트)
5. [문제 해결](#문제-해결)

---

## 번역 시스템 개요

HanNetHack은 두 가지 번역 메커니즘을 사용합니다:

### 1. gettext (C 소스 코드)

```
src/*.c의 _("메시지") → po/nethack.pot → po/ko.po → nethack.mo
```

- 런타임에 `gettext()` 함수가 번역을 조회
- `po/ko.po` 파일 하나로 모든 C 소스 메시지 관리

### 2. 파일 교체 (데이터 파일, Lua)

```
dat/help → dat/locale/ko/help (우선 로드)
dat/nhlib.lua → dat/locale/ko/nhlib.lua (우선 로드)
```

- `dlb_fopen()` 함수가 자동으로 `locale/{lang}/` 디렉토리를 먼저 확인
- 한국어 파일이 있으면 사용, 없으면 영어 원본 사용
- 소스 코드: `src/dlb.c:478-491`

```c
// dlb_fopen() 동작 방식
lang = get_current_language();  // "ko"
snprintf(locale_name, ..., "locale/%s/%s", lang, name);  // "locale/ko/help"
if (do_dlb_fopen(dp, locale_name, mode)) {  // 한국어 파일 시도
    return dp;
}
// 실패 시 원본 파일 사용
```

### 번역 파일 위치

```
po/
├── nethack.pot          # 번역 템플릿 (xgettext로 생성)
└── ko.po                # 한국어 번역

dat/locale/ko/
├── LC_MESSAGES/
│   └── nethack.mo       # 컴파일된 gettext 번역
├── help                 # 메인 도움말
├── hh                   # 빠른 도움말
├── cmdhelp              # 명령어 도움말
├── nhcore.lua           # 시스템 콜백
├── nhlib.lua            # 튜토리얼
├── quest.lua            # 퀘스트 대사
└── ...                  # 기타 번역 파일
```

---

## 파일 유형별 전략

### 1. C 소스 코드 메시지 (`src/*.c`)

**메커니즘:** gettext `_()` 매크로로 래핑된 문자열 → `po/nethack.pot` → `po/ko.po`

**업스트림 변경 시 처리:**

```bash
# 1. 업스트림 병합 후 .pot 파일 재생성
xgettext --keyword=_ --keyword=N_ --language=C \
  --add-comments --sort-output --from-code=UTF-8 \
  -o po/nethack.pot src/*.c

# 2. 기존 ko.po에 새 문자열 병합
msgmerge --update --backup=none po/ko.po po/nethack.pot

# 3. 통계 확인 (fuzzy/untranslated 확인)
msgfmt --statistics po/ko.po -o /dev/null

# 4. 새 문자열 번역 추가
# fuzzy 제거하고 번역 수정

# 5. 컴파일
msgfmt -c -o dat/locale/ko/LC_MESSAGES/nethack.mo po/ko.po
```

**주의사항:**
- 새로 추가된 `_()` 래핑이 없는 메시지 확인 필요
- 검색 패턴: `grep -r "pline(\"" src/*.c | grep -v "_(\""`

---

### 2. Lua 파일 (`dat/*.lua`)

**메커니즘:** 파일 교체 방식 (`dat/locale/ko/*.lua`)

**번역이 필요한 Lua 파일:**
- `nhcore.lua` - 시스템 콜백, farlook 팁
- `nhlib.lua` - 튜토리얼 메시지
- `quest.lua` - 퀘스트 대사
- `themerms.lua` - 테마룸 메시지
- `tut-*.lua` - 튜토리얼 레벨
- `air.lua`, `earth.lua`, `water.lua`, `astral.lua` - 엔드게임 메시지
- `minend-2.lua` - 광산 메시지

**업스트림 변경 시 처리:**

```bash
# 1. 변경된 Lua 파일 확인
git diff upstream/master --name-only -- 'dat/*.lua'

# 2. 메시지가 있는 파일만 필터링
for f in $(git diff upstream/master --name-only -- 'dat/*.lua'); do
  if grep -q "pline\|verbalize\|nh.text" "$f"; then
    echo "번역 업데이트 필요: $f"
  fi
done

# 3. diff로 변경 내용 확인
git diff upstream/master -- dat/nhlib.lua

# 4. 한국어 파일에 동일한 변경 적용
# dat/locale/ko/nhlib.lua 수동 편집
```

**주의사항:**
- 레벨 맵 파일(Xxx-loca.lua 등)은 대부분 메시지 없음
- 새 메시지 함수: `nh.pline()`, `nh.verbalize()`, `nh.text()`, `nh.getlin()`

---

### 3. 텍스트 도움말 파일 (`dat/help`, `dat/cmdhelp` 등)

**메커니즘:** 파일 교체 방식 (`dat/locale/ko/*`)

**번역된 파일 목록:**
```
dat/locale/ko/
├── help          # 메인 도움말
├── hh            # 빠른 도움말
├── cmdhelp       # 명령어 도움말
├── keyhelp       # 키 도움말
├── opthelp       # 옵션 도움말
├── optmenu       # 옵션 메뉴
├── usagehlp      # 사용법 도움말
├── wizhelp       # 위저드 모드 도움말
├── history       # 역사
├── bogusmon.txt  # 가짜 몬스터 이름
├── engrave.txt   # 각인 메시지
├── epitaph.txt   # 묘비명
├── oracles.txt   # 신탁
├── rumors.fal    # 거짓 소문
└── rumors.tru    # 진짜 소문
```

**업스트림 변경 시 처리:**

```bash
# 1. 변경된 파일 확인
git diff upstream/master --name-only -- dat/help dat/hh dat/cmdhelp \
  dat/keyhelp dat/opthelp dat/optmenu

# 2. 변경 내용 비교
diff -u dat/help dat/locale/ko/help

# 3. 한국어 파일에 변경 반영
# 수동으로 새 내용 번역 추가
```

---

### 4. 데이터 파일

**메커니즘:** `dlb_fopen()`이 자동으로 `locale/{lang}/` 디렉토리를 먼저 확인

| 파일 | 설명 | 번역 상태 | 비고 |
|------|------|----------|------|
| `data.base` → `data` | 백과사전 (291KB) | ⚠️ 미번역 | 파일 교체 가능 |
| `license` | 라이선스 | ❌ 원본 유지 | 법적 문서 |
| `rumors.*` | 소문 | ✅ 번역됨 | |
| `oracles.txt` | 신탁 | ✅ 번역됨 | |

**data.base 번역 방법:**

```bash
# 1. data.base 복사 및 번역
cp dat/data.base dat/locale/ko/data.base
# 수동으로 내용 번역

# 2. 컴파일 (makedefs 사용)
# data.base → data 로 컴파일됨
cd dat/locale/ko
../../util/makedefs -d

# 또는 Makefile 사용
make data -C dat/locale/ko
```

**참고:** `data.base`는 약 1,200개 항목이 있는 대규모 파일입니다.
점진적 번역을 권장합니다.

---

## 업스트림 병합 절차

### 전체 워크플로우

```bash
# 1. 업스트림 가져오기
git fetch upstream
git checkout feature/your-branch
git merge upstream/master

# 2. 충돌 해결 (있다면)
# ko.po 충돌: 양쪽 번역 모두 유지
# locale/ko/* 충돌: 한국어 버전 우선

# 3. 새 번역 가능 문자열 확인
./scripts/i18n-check.sh  # (아래 스크립트 참조)

# 4. 번역 업데이트
# - po/ko.po 편집
# - dat/locale/ko/* 편집

# 5. 컴파일 및 테스트
make
msgfmt -c -o dat/locale/ko/LC_MESSAGES/nethack.mo po/ko.po

# 6. 커밋
git add po/ko.po po/nethack.pot dat/locale/ko/
git commit -m "Update Korean translations for upstream merge"
```

---

## 자동화 스크립트

### `scripts/i18n-check.sh`

```bash
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
    if ! diff -q "$f" "dat/locale/ko/$(basename $f)" > /dev/null 2>&1; then
      echo "변경됨: $f"
    fi
  fi
done

echo ""
echo "=== 5. 도움말 파일 변경 확인 ==="
for f in help hh cmdhelp keyhelp opthelp; do
  if ! diff -q "dat/$f" "dat/locale/ko/$f" > /dev/null 2>&1; then
    echo "확인 필요: dat/$f vs dat/locale/ko/$f"
  fi
done
```

### `scripts/i18n-update.sh`

```bash
#!/bin/bash
# 번역 파일 업데이트

echo "=== .pot 파일 재생성 ==="
xgettext --keyword=_ --keyword=N_ --language=C \
  --add-comments --sort-output --from-code=UTF-8 \
  -o po/nethack.pot src/*.c

echo "=== ko.po 병합 ==="
msgmerge --update --backup=none po/ko.po po/nethack.pot

echo "=== 컴파일 ==="
msgfmt -c -v -o dat/locale/ko/LC_MESSAGES/nethack.mo po/ko.po

echo "=== 완료 ==="
msgfmt --statistics po/ko.po -o /dev/null 2>&1
```

---

## 문제 해결

### Q: msgfmt에서 format specification 오류가 발생함

```
po/ko.po:1234: number of format specifications in 'msgid' and 'msgstr' does not match
```

**해결:** 원문과 번역의 `%s`, `%d` 등 포맷 지정자 개수가 일치해야 함.

```
# 잘못된 예
msgid "You hit %s."
msgstr "맞았다."  # %s 누락

# 올바른 예
msgid "You hit %s."
msgstr "%s{을/를} 맞혔다."
```

### Q: fuzzy 번역이 많이 생김

업스트림에서 원문이 약간 변경되면 fuzzy로 표시됨.

```bash
# fuzzy 항목 찾기
grep -B2 "^#, fuzzy" po/ko.po | grep "msgid"

# fuzzy 해제: #, fuzzy 줄에서 "fuzzy, " 또는 ", fuzzy" 제거
```

### Q: 새로 추가된 Lua 파일에 메시지가 있는지 확인

```bash
# 새 Lua 파일 중 메시지가 있는 것 찾기
for f in dat/*.lua; do
  if [ ! -f "dat/locale/ko/$(basename $f)" ]; then
    if grep -q "pline\|verbalize\|nh.text" "$f"; then
      echo "번역 필요: $f"
    fi
  fi
done
```

### Q: 조합 패턴 번역이 이상함

문자열이 조합되어 출력되는 경우, 개별 문자열 번역이 맞아도 조합 결과가 어색할 수 있음.

**확인 방법:**
```bash
# msgid에 %s가 없는데 msgstr에 %s가 있는 경우 찾기
grep -B1 "^msgstr" po/ko.po | grep -A1 "^msgid \"[^%\"]*\"$" | \
  grep -v "^--$" | grep -B1 "msgstr \".*%s" | grep "msgid"
```

**해결:** 소스 코드에서 조합 패턴 확인 후 번역 수정.

---

## 참고 자료

- [GNU gettext 매뉴얼](https://www.gnu.org/software/gettext/manual/)
- [NetHack 소스 코드](https://github.com/NetHack/NetHack)
- `po/ko.po` 내 주석 - 조합 패턴 설명 포함

---

*최종 업데이트: 2026-01-31*
