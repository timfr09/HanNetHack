# HanNetHack 업스트림 병합 가이드

이 문서는 NetHack 업스트림에서 변경 사항을 가져올 때 한국어 번역을 유지하는 방법을 설명합니다.

## 목차

1. [번역 시스템 개요](#번역-시스템-개요)
2. [파일 유형별 전략](#파일-유형별-전략)
3. [업스트림 병합 절차](#업스트림-병합-절차)
4. [머지 PR vs 번역 PR](#머지-pr-vs-번역-pr)
5. [충돌 해결 전략](#충돌-해결-전략)
6. [자동화 스크립트](#자동화-스크립트)
7. [문제 해결](#문제-해결)

---

## 번역 시스템 개요

HanNetHack은 두 가지 번역 메커니즘을 사용합니다:

### 1. gettext (C 소스 코드)

```
src/*.c의 _("메시지") → po/nethack.pot → po/ko_manual.po → ko_merged.po → dat/locale/ko/nethack.mo → nhdat 번들
                              └─ (선택) make update-po → 로컬 ko.po 캐시 (신규 msgid 조회·fallback)
```

- 런타임에는 GNU libintl 대신 **`src/mo_reader.c`** 가 DLB 안의 `nethack.mo`를 읽고, `_()` 는 **`nh_gettext()`** 로 조회됩니다.
- **ko_manual.po**: 저장소에 커밋되는 **유일한** 한국어 번역 원본. 편집·리뷰·PR 대상은 여기만.
- **ko.po**: `make update-po` / `safe-update` 가 POT에서 만드는 **로컬 전용 캐시**(gitignored). 번역 저장소가 아님. 없어도 `make compile` 은 `ko_manual.po` 만으로 동작.
- **ko_merged.po**: 빌드 시 `msgcat --use-first ko_manual.po [ko.po]`(캐시가 있을 때만 후자 참여)로 생성.
- 동일 msgid는 항상 **ko_manual.po** 쪽이 이깁니다.

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
├── ko_manual.po         # 한국어 번역 유일 원본 (커밋·편집 대상)
├── ko.po                # 로컬 전용 캐시 (gitignored, 선택; 없어도 됨)
└── ko_merged.po         # 빌드 시 자동 생성

dat/locale/ko/
├── nethack.mo           # 컴파일된 gettext 번역 (nhdat에 번들됨)
├── help                 # 메인 도움말
├── hh                   # 빠른 도움말
├── cmdhelp              # 명령어 도움말
├── nhcore.lua           # 시스템 콜백
├── nhlib.lua            # 튜토리얼
├── quest.lua            # 퀘스트 대사
└── ...                  # 기타 번역 파일
```

### ko_manual.po / ko.po 역할

| 파일 | 역할 | Git |
|------|------|-----|
| `ko_manual.po` | **유일한** 한국어 번역 원본. 모든 `msgstr`는 여기만 편집 | 커밋 |
| `ko.po` | POT 대비 신규·변경 msgid를 보기 위한 **작업용 캐시**. 번역을 쌓지 않음 | ignore |

`make safe-update` / `update-po`는 로컬 `ko.po`만 갱신한다. 예전에 `ko.po`에
수동 번역을 두던 시절의 잔재가 아니라, **새 문자열 목록을 뽑는 다리**다.
발견한 msgid는 `ko_manual.po`로 옮겨 번역하고, `make compile`로 끝낸다.
캐시가 있으면 병합 시 `ko_manual.po`에 아직 없는 항목만 fallback으로 쓰인다.

**편집 규칙: `ko_manual.po`만 직접 편집.** `ko.po`는 저장소에 올리지 않는다.

---

## 파일 유형별 전략

### 1. C 소스 코드 메시지 (`src/*.c`)

**메커니즘:** gettext `_()`, `C_()`, `N_()` 매크로로 래핑된 문자열

```
src/*.c → xgettext → po/nethack.pot
                         │
                         ├─→ (선택) msgmerge → 로컬 ko.po  # 신규 msgid 조회용
                         │
                         └─→ 번역은 전부 po/ko_manual.po에 추가/수정
                                    ↓ msgcat --use-first (+ 있으면 ko.po)
                              ko_merged.po → nethack.mo
```

**업스트림 변경 시 처리 (po/Makefile 사용):**

```bash
# 1. 업스트림 병합 후 .pot 파일 재생성
cd po && make pot

# 2. (선택) 로컬 ko.po 캐시 갱신 — 새 msgid 목록 확인용
make safe-update

# 3. 새/변경 문자열 → ko_manual.po에만 번역 추가
# (필요 시: python3 sync_new_msgids_to_manual.py)

# 4. 컴파일 (merge + compile; ko.po 없어도 동작)
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
git diff upstream/NetHack-5.0 --name-only -- 'dat/*.lua'

# 2. 메시지가 있는 파일만 필터링
for f in $(git diff upstream/NetHack-5.0 --name-only -- 'dat/*.lua'); do
  if grep -q "pline\|verbalize\|nh.text" "$f"; then
    echo "번역 업데이트 필요: $f"
  fi
done

# 3. diff로 변경 내용 확인
git diff upstream/NetHack-5.0 -- dat/nhlib.lua

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
# 1. 동기화 백로그 (어디가 어긋났는지)
./scripts/check-locale-dat-sync.sh

# 2. 변경된 파일 확인
git diff upstream/NetHack-5.0 --name-only -- dat/help dat/hh dat/cmdhelp \
  dat/keyhelp dat/opthelp dat/optmenu dat/history dat/oracles.txt

# 3. 변경 내용 비교
diff -u dat/opthelp dat/locale/ko/opthelp

# 4. 한국어 파일에 변경 반영 (문단·옵션·항목 단위 — 줄 1:1 번역 금지)
#    절차: po/TRANSLATION_PROCESS.md §2.E
```

---

### 4. 데이터 파일

**메커니즘:** `dlb_fopen()`이 자동으로 `locale/{lang}/` 디렉토리를 먼저 확인

| 파일 | 설명 | 번역 상태 | 비고 |
|------|------|----------|------|
| `data.base` → `data` | 백과사전 | ✅ `dat/locale/ko/data.base` (서술문 번역) | 런타임은 컴파일된 `locale/ko/data` |
| `license` | 라이선스 | ❌ 원본 유지 | 법적 문서 |
| `rumors.*` | 소문 | ✅ 번역됨 | |
| `oracles.txt` | 신탁 | ✅ 번역됨 | |

**백과사전 (`data.base`) 운영:**

- 편집 원본: `dat/locale/ko/data.base` (커밋). 조회 키·`~` 제외 패턴·`*` 헤더는 영어 유지.
- 게임은 `dlb_fopen("data")` → `locale/ko/data`를 먼저 연다. **소스(`data.base`)만 넣으면 안 된다.**
- 빌드: `sh scripts/build-locale-rnddata.sh` 가 `data.base` → `locale/ko/data`로 컴파일하고, Unix/`Makefile.nmake`가 nhdat에 번들한다.

```bash
# 업스트림에서 영어 백과가 바뀐 뒤
diff -u dat/data.base dat/locale/ko/data.base | less
# 변경 항목만 한국어로 반영한 다음:
sh scripts/build-locale-rnddata.sh
# 이후 make all / nmake 로 nhdat 재생성
```

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
# 1. 업스트림 가져오기 (추적 브랜치: NetHack-5.0)
git fetch upstream NetHack-5.0

# 2. 업스트림 변경 사항 사전 분석
#    - 어떤 파일이 변경되었는지 확인
#    - i18n 래핑된 파일과 겹치는지 확인
git log --oneline HEAD..upstream/NetHack-5.0
git log --oneline --stat upstream/NetHack-5.0 -N  # N = 새 커밋 수

# 3. 병합
git merge upstream/NetHack-5.0 --no-edit

# 4. 충돌 해결 (있다면) → "충돌 해결 전략" 섹션 참조

# 5. 번역 파일 업데이트
cd po
make pot              # nethack.pot 재생성
make safe-update      # (선택) 로컬 ko.po 캐시 갱신 — 신규 msgid 조회용
make compile          # ko_manual.po 기준 merge + compile

# 6. 새 메시지에 대한 번역 추가
#    - make untranslated로 미번역 문자열 확인
#    - ko_manual.po에만 번역 추가
make untranslated
# ko_manual.po 편집
make compile          # 다시 컴파일

# 7. 빌드 테스트 (루트에서; -j 비권장)
cd .. && make all

# 8. 커밋 (번역 원본만 — ko.po는 커밋하지 않음)
git add po/ko_manual.po po/nethack.pot
git commit -m "Update translations after upstream merge"
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

## 머지 PR vs 번역 PR

커밋이 히스토리에 섞여도 **최종 트리만 맞으면 동작에는 문제 없다.** 다만 리뷰·bisect·체리픽을 위해 **PR(또는 커밋)을 나눈다.** 과거 히스토리를 rewrite 하지는 않는다.

| PR | 넣을 것 | 넣지 말 것 |
|----|---------|------------|
| **업스트림 머지** | 충돌 해결, `_()` 재래핑, 빌드 통과, **새 msgid·깨진 조합의 최소 번역** | `ko_manual.po` / `dat/locale/ko/` **대량 문체 다듬기** |
| **번역 전용** (`i18n(ko):` / `fix(i18n/ko):`) | `po/ko_manual.po`, `dat/locale/ko/`, 필요 시 `nethack.mo` | 업스트림 코드·충돌 해결과 무관한 게임 로직 |

한 PR 안에 여러 커밋이어도 의도가 보이게 나눈다: `merge: …` → `i18n(ko): fill new strings` → (별 PR) `i18n(ko): polish …`.

추적:

```bash
git log -- po/ko_manual.po dat/locale/ko/
git log --grep='i18n(ko)\|fix(i18n/ko)'
```

운영 쪽 짧은 요약은 [po/TRANSLATION_PROCESS.md](../po/TRANSLATION_PROCESS.md) §3.A.

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
make safe-update  # (선택) 로컬 ko.po 캐시 갱신 (자동 백업)
make merge        # ko_manual.po (+ 있으면 ko.po) → ko_merged.po
make compile      # merge + 컴파일 → dat/locale/ko/nethack.mo
make stats        # 번역 통계
make check        # 번역 오류 검사
make untranslated # 미번역 문자열 목록
make fuzzy        # fuzzy 번역 목록
make clean        # 생성 파일 삭제
```

### `scripts/merge-upstream.sh`

업스트림 병합 보조 스크립트. 기본 추적 브랜치는 **`upstream/NetHack-5.0`**.

```bash
./scripts/merge-upstream.sh                 # upstream/NetHack-5.0
./scripts/merge-upstream.sh upstream/NetHack-5.0

# 수동으로 동일한 흐름을 밟을 때:
git fetch upstream NetHack-5.0
git log --oneline HEAD..upstream/NetHack-5.0
git merge upstream/NetHack-5.0 --no-edit
cd po && make pot && make safe-update && make compile && make stats && make untranslated
# 새 msgid → ko_manual.po에 번역 후 make compile
cd .. && make all   # -j 비권장
```

---

## 문제 해결

### Q: msgfmt에서 format specification 오류가 발생함

```
po/ko_manual.po:1234: number of format specifications in 'msgid' and 'msgstr' does not match
```

**해결:** `ko_manual.po`에서 원문과 번역의 `%s`, `%d` 등 포맷 지정자 개수를 맞춘다.

```
# 잘못된 예
msgid "You hit %s."
msgstr "맞았다."  # %s 누락

# 올바른 예
msgid "You hit %s."
msgstr "%s{을/를} 맞혔다."
```

### Q: fuzzy 번역이 많이 생김

`make safe-update`로 만든 **로컬 `ko.po` 캐시**에서 업스트림 원문이 약간 바뀌면
fuzzy로 표시될 수 있다. 캐시의 fuzzy는 커밋 대상이 아니다.

```bash
# (선택) 캐시에서 변경 후보 msgid 찾기
grep -B2 "^#, fuzzy" po/ko.po | grep "msgid"

# 실제 번역 수정은 항상 ko_manual.po에서
# fuzzy 플래그가 ko_manual.po에 있으면 문맥에 맞게 고친 뒤 제거
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

`C_("context", "string")` 사용 시 **`ko_manual.po`에만** `msgctxt` 포함한 항목이 있으면 된다:

```
msgctxt "moon"
msgid "full"
msgstr "보름"
```

`make pot`으로 POT에 컨텍스트가 잡혔는지 확인하고, 번역은 `ko_manual.po`에 추가한 뒤
`make compile`하면 된다. 로컬 `ko.po` 캐시는 필수가 아니다.

---

## 참고 자료

- [GNU gettext 매뉴얼](https://www.gnu.org/software/gettext/manual/)
- [NetHack 소스 코드](https://github.com/NetHack/NetHack)
- `po/ko_manual.po` — 한국어 번역 유일 원본 (편집 대상)
- `po/TRANSLATION_GUIDE_KO.md` — 한국어 번역 가이드 상세
- `po/I18N_SYSTEM.md` — i18n 시스템 기술 문서

---

*최종 업데이트: 2026-10-18*
