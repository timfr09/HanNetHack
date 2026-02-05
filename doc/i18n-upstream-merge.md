# HanNetHack 업스트림 병합 가이드

이 문서는 NetHack 업스트림에서 변경 사항을 가져올 때 한국어 번역을 유지하는 방법을 설명합니다.

## 목차

1. [번역 시스템 개요](#번역-시스템-개요)
2. [파일 유형별 전략](#파일-유형별-전략)
3. [업스트림 병합 절차](#업스트림-병합-절차)
4. [충돌 해결 전략](#충돌-해결-전략)
5. [자동화 스크립트](#자동화-스크립트)
6. [문제 해결](#문제-해결)

---

## 번역 시스템 개요

HanNetHack은 두 가지 번역 메커니즘을 사용합니다:

### 1. gettext (C 소스 코드)

```
src/*.c의 _("메시지") → po/nethack.pot → po/ko.po + ko_manual.po → nethack.mo
```

- 런타임에 `gettext()` 함수가 번역을 조회
- **ko_manual.po**: 수동으로 관리하는 번역 (절대 자동 덮어쓰기 안 됨, 우선권)
- **ko.po**: `xgettext`/`msgmerge`로 자동 관리되는 번역 (덮어쓰기 가능)
- **ko_merged.po**: 빌드 시 `msgcat --use-first ko_manual.po ko.po`로 자동 생성
- `ko_manual.po`의 번역이 항상 `ko.po`보다 우선

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
├── Makefile             # 번역 빌드 시스템 (make pot, make compile 등)
├── nethack.pot          # 번역 템플릿 (xgettext로 생성)
├── ko.po                # 한국어 번역 (자동 관리, 덮어쓰기 가능!)
├── ko_manual.po         # 한국어 수동 번역 (우선권, 안전)
└── ko_merged.po         # 빌드 시 자동 생성 (ko_manual.po + ko.po)

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

### ko_manual.po를 쓰는 이유

`make safe-update`나 `make update-po`는 `ko.po`를 업스트림 변경에 맞춰 자동으로
수정합니다. 이 과정에서 수동으로 세심하게 조정한 번역이 fuzzy로 표시되거나
덮어쓰기될 수 있습니다. `ko_manual.po`에 넣은 번역은 이 과정에서 절대 영향받지 않으며,
빌드 시 `msgcat --use-first`로 합칠 때 항상 우선권을 가집니다.

**편집 규칙: `ko_manual.po`만 직접 편집. `ko.po`는 자동 관리 전용.**

---

## 파일 유형별 전략

### 1. C 소스 코드 메시지 (`src/*.c`)

**메커니즘:** gettext `_()`, `C_()`, `N_()` 매크로로 래핑된 문자열

```
src/*.c → xgettext → po/nethack.pot → msgmerge → po/ko.po
                                                   ↓
                                    po/ko_manual.po + ko.po
                                                   ↓ msgcat --use-first
                                            ko_merged.po → ko.mo
```

**업스트림 변경 시 처리 (po/Makefile 사용):**

```bash
# 1. 업스트림 병합 후 .pot 파일 재생성
cd po && make pot

# 2. ko.po 안전 업데이트 (자동 백업)
make safe-update

# 3. 새 문자열 중 수동 번역 필요한 것 → ko_manual.po에 추가
# (ko.po는 직접 편집하지 않음)

# 4. 컴파일 (merge + compile 자동 수행)
make compile

# 5. 통계 확인
make stats
```

**주의사항:**
- 새로 추가된 `_()` 래핑이 없는 메시지 확인 필요
- 업스트림 커밋에서 새 pline/You/verbalize 등의 메시지를 추가했다면 i18n 래핑 필요
- `C_("context", "string")` 사용 시 ko_manual.po에 `msgctxt` 항목 추가 필요

**i18n 래핑 키워드:**
- `_("string")` — 기본 번역
- `C_("context", "string")` — 동음이의어 구분 (예: `C_("moon", "full")` vs `_("full")`)
- `N_("string")` — 지연 번역 (컴파일 타임에 등록, 런타임에 번역)
- `P_("singular", "plural")` — 복수형 (한국어는 보통 불필요)

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

### Git 리모트 설정

```bash
# origin = HanNetHack 포크 (push 가능)
git remote add origin git@github.com:timfr09/HanNetHack.git

# upstream = NetHack 원본 (fetch만, push 금지)
git remote add upstream https://github.com/NetHack/NetHack.git
git remote set-url --push upstream no_push
```

### 전체 워크플로우

```bash
# 1. 업스트림 가져오기
git fetch upstream NetHack-3.7

# 2. 업스트림 변경 사항 사전 분석
#    - 어떤 파일이 변경되었는지 확인
#    - i18n 래핑된 파일과 겹치는지 확인
git log --oneline HEAD..upstream/NetHack-3.7
git log --oneline --stat upstream/NetHack-3.7 -N  # N = 새 커밋 수

# 3. 병합
git merge upstream/NetHack-3.7 --no-edit

# 4. 충돌 해결 (있다면) → "충돌 해결 전략" 섹션 참조

# 5. 번역 파일 업데이트
cd po
make pot              # nethack.pot 재생성
make safe-update      # ko.po 안전 업데이트 (백업 생성)
make compile          # merge + compile

# 6. 새 메시지에 대한 번역 추가
#    - make untranslated로 미번역 문자열 확인
#    - ko_manual.po에 번역 추가
make untranslated
# ko_manual.po 편집
make compile          # 다시 컴파일

# 7. 빌드 테스트
cd .. && make -C sys/unix all  # 또는 프로젝트 빌드 명령

# 8. 커밋
git add po/ko_manual.po po/nethack.pot
git commit --author="timfr09 <crefrog@gmail.com>" \
  -m "Update translations after upstream merge"
```

### 사전 분석이 중요한 이유

업스트림 커밋이 다음 파일을 수정했는지 반드시 확인:

| 파일 유형 | 충돌 가능성 | 확인 사항 |
|-----------|------------|----------|
| `src/*.c` (i18n 래핑됨) | **높음** | `_()`, `C_()` 래핑 주변 코드 변경 |
| `include/*.h` | 보통 | 새 선언, 매크로 변경 |
| `dat/*.lua` | 보통 | 메시지 변경 여부 |
| `doc/*`, `sys/*` | 낮음 | 보통 충돌 없음 |
| `po/*` | 없음 | 업스트림에 po/ 없음 |

---

## 충돌 해결 전략

### C 소스 코드 충돌 (`src/*.c`)

HanNetHack에서 수정한 C 소스 파일은 크게 두 종류:

#### 1. i18n 래핑만 한 경우 (대부분)

```c
// 업스트림 원본
pline("You hit the monster.");

// HanNetHack 수정
pline(_("You hit the monster."));
```

**충돌 해결:** 업스트림 코드를 가져온 후 `_()` 래핑을 다시 적용.

```c
// 업스트림이 메시지를 변경한 경우
// 업스트림: pline("You strike the monster.");
// 해결:
pline(_("You strike the monster."));
// 그리고 ko_manual.po에 새 번역 추가
```

#### 2. 조합 패턴 수정 (insight.c 등)

```c
// 업스트림이 로직을 변경한 경우
// HanNetHack의 C_(), 포맷 문자열 수정 등도 반영해야 함
```

**충돌 해결 순서:**
1. 업스트림 로직 변경을 먼저 이해
2. HanNetHack의 i18n 래핑과 C_() 컨텍스트를 다시 적용
3. 새 메시지의 조합 패턴을 분석하여 ko_manual.po에 번역 추가

### PO 파일 충돌

업스트림에는 `po/` 디렉토리가 없으므로 PO 파일 충돌은 발생하지 않습니다.
HanNetHack 내부에서 여러 브랜치가 ko_manual.po를 동시에 수정할 경우:

```bash
# 양쪽의 번역을 모두 유지 (msgcat으로 병합)
msgcat --use-first branch_a.po branch_b.po -o merged.po
```

### 한국어 조사 시스템 충돌

`src/ko_postpos.c`, `include/ko_postpos.h`, `src/objnam.c` 등에 있는 한국어
조사 처리 코드(`{이/가}`, `{을/를}` 등)는 업스트림에 없는 코드이므로,
업스트림이 같은 함수를 수정하면 충돌 가능.

**해결:** 업스트림 변경을 먼저 적용한 후 한국어 조사 처리를 다시 적용.

---

## 자동화 스크립트

### po/Makefile 타겟 (권장)

`po/Makefile`에 필요한 모든 빌드 타겟이 이미 정의되어 있습니다:

```bash
cd po

make pot          # 소스에서 nethack.pot 재생성
make safe-update  # ko.po 안전 업데이트 (자동 백업)
make merge        # ko_manual.po + ko.po → ko_merged.po
make compile      # merge + 컴파일 (ko.mo 생성)
make stats        # 번역 통계
make check        # 번역 오류 검사
make untranslated # 미번역 문자열 목록
make fuzzy        # fuzzy 번역 목록
make clean        # 생성 파일 삭제
```

### `scripts/merge-upstream.sh`

업스트림 병합 전체 과정을 자동화하는 스크립트:

```bash
#!/bin/bash
# 업스트림 병합 스크립트
set -e

echo "=== 1. 업스트림 fetch ==="
git fetch upstream NetHack-3.7

echo ""
echo "=== 2. 새 업스트림 커밋 확인 ==="
NEW_COMMITS=$(git log --oneline HEAD..upstream/NetHack-3.7 | wc -l)
if [ "$NEW_COMMITS" -eq 0 ]; then
    echo "업스트림과 동기화되어 있습니다."
    exit 0
fi
echo "$NEW_COMMITS 개의 새 커밋:"
git log --oneline HEAD..upstream/NetHack-3.7

echo ""
echo "=== 3. 변경된 파일 확인 ==="
git log --stat HEAD..upstream/NetHack-3.7

echo ""
echo "=== 4. 병합 ==="
git merge upstream/NetHack-3.7 --no-edit

echo ""
echo "=== 5. POT 파일 재생성 ==="
cd po
make pot

echo ""
echo "=== 6. ko.po 안전 업데이트 ==="
make safe-update

echo ""
echo "=== 7. 컴파일 ==="
make compile

echo ""
echo "=== 8. 통계 ==="
make stats

echo ""
echo "=== 9. 미번역 문자열 ==="
make untranslated

echo ""
echo "=== 완료 ==="
echo "필요시 ko_manual.po에 새 번역을 추가한 후 make compile을 실행하세요."
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

**핵심 예시 — insight.c의 enl_msg 매크로:**

```c
// 영어: " prefix verb suffix postscript."  (SVO)
Sprintf(buf, _(" %s%s%s%s."), start, middle, end, ps);
// %1$s=prefix, %2$s=verb, %3$s=suffix, %4$s=postscript

// 한국어: " prefix suffix verb postscript."  (SOV)
// ko_manual.po에서 포맷 문자열 재배열:
msgid " %s%s%s%s."
msgstr " %1$s%3$s%2$s%4$s."
```

**조합 패턴 번역 규칙:**
1. 접미사(suffix)에 한국어 서술어가 포함된 경우 → 동사 슬롯에 영폭 공백(​) 사용
2. 영어 "have "/"are "/"is " 등 → "​" (영폭 공백)으로 번역하여 빈 동사 슬롯
3. 접미사에 선행 공백 없이, 후행 공백 포함 (SOV 어순에서 동사 앞에 공백)
4. `C_("context", "string")` 사용하여 동음이의어 구분

**해결:** 소스 코드에서 조합 패턴 확인 후 번역 수정.

### Q: C_() 컨텍스트 항목이 번역이 안 됨

`C_("context", "string")` 사용 시 ko_manual.po에 `msgctxt` 포함한 항목 필요:

```
msgctxt "moon"
msgid "full"
msgstr "보름"
```

**그리고** ko.po에도 해당 항목이 있어야 합니다. `make pot && make safe-update` 후
ko.po에 새 `msgctxt` 항목이 자동 추가되지만, fuzzy 플래그가 붙을 수 있으므로 확인 필요.

---

## 참고 자료

- [GNU gettext 매뉴얼](https://www.gnu.org/software/gettext/manual/)
- [NetHack 소스 코드](https://github.com/NetHack/NetHack)
- `po/ko_manual.po` — 수동 번역 (편집 대상)
- `po/TRANSLATION_GUIDE_KO.md` — 한국어 번역 가이드 상세
- `po/I18N_SYSTEM.md` — i18n 시스템 기술 문서

---

*최종 업데이트: 2026-02-05*
