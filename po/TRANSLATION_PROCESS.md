# HanNetHack 번역 프로세스 (운영 가이드)

규칙·문체·조사 처리 등 **번역 품질 규약**은 [TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md)를 따르고, 여기서는 **언제 무엇을 실행하는지**만 정리한다. 시스템 구조는 [I18N_SYSTEM.md](I18N_SYSTEM.md), 업스트림 병합 절차는 [doc/i18n-upstream-merge.md](../doc/i18n-upstream-merge.md)를 본다.

---

## 1. 산출물이 나뉘는 이유

| 경로 | 역할 | Git |
|------|------|-----|
| `po/ko_manual.po` | 한국어 **유일의 수동 편집** 소스 | 커밋 |
| `po/ko.po` | `nethack.pot`에서 갱신되는 **로컬 캐시** (새 msgid 조회용) | 보통 무시 |
| `po/ko_merged.po` | `msgcat` 병합 결과 | 생성물 |
| `dat/locale/ko/nethack.mo` | `msgfmt` 출력 (게임이 읽는 카탈로그) | `make compile`로 갱신 |
| `dat/locale/ko/*.lua`, `help` 등 | PO 밖 **데이터/스크립트** 직접 번역 | 각각 커밋 |

`make compile`은 `ko_manual.po`만 있어도 동작한다. `ko.po`는 있으면 병합 시 **아직 `ko_manual.po`에 없는** 자동 추출 항목을 채우는 데 쓰인다(우선순위는 항상 `ko_manual.po`).

---

## 2. 작업 유형별 권장 절차

### A. 기존 문구만 손질 (가장 흔함)

1. `po/ko_manual.po` 편집 (필요 시 `dat/locale/ko/` 하위 데이터 파일).
2. `cd po && make compile` — 병합·`nethack.mo` 생성·`../dat/locale/ko/` 복사.
3. 저장소 루트에서 `make all` — `nhdat`에 `.mo` 반영.
4. (PR 전) `scripts/translation-preflight.sh` 권장.

### B. 소스에 **새로** `_("...")`를 넣었거나 업스트림에서 C 문자열이 바뀐 경우

1. `cd po && make pot` — C·Lua에서 `nethack.pot` 갱신.
2. `cd po && make safe-update` — 로컬 `ko.po`를 POT에 맞게 갱신(백업 생성).
3. **새/변경 msgid**를 `ko_manual.po`에 옮겨 적어 번역.
4. `make compile` → 루트에서 `make all`.
5. (PR 전) `translation-preflight.sh` + 래핑 검사는 이미 스크립트에 포함.

### C. Lua 퀘스트/튜토리얼 등 (PO + 로케일 복제)

- `dat/*.lua`는 `xgettext` 대상이지만, 한국어는 보통 `dat/locale/ko/동일파일.lua`에 **전체 복제·번역**하는 패턴이 있다. EN과 KO의 `pline` / `nh.text` 호출 수를 맞추는지 [scripts/i18n-check.sh](../scripts/i18n-check.sh)로 가끔 확인할 수 있다.

### D. 기존 번역 **품질 다듬기** (신규 채움이 아님)

미번역 채우기와 달리, **이미 들어 있는 `msgstr`를 고치는 작업**은 PO 안에서만 예쁜 문장이 되면 끝이 아니라, **빌드된 게임 안에서 실제로 출력될 때** 읽기 좋은지가 기준이다.

#### 절차 (권장 순서)

1. **범위 정하기** — 어떤 플레이 구간(초반·전투·상점·튜토리얼·종료 화면 등) 또는 어떤 파일/기능 주변인지 정한다.
2. **맥락 확인** — 해당 `msgid`가 소스에서 어떻게 쓰이는지 본다. 저장소 루트에서 예:
   ```bash
   rg -n 'msgid_here' src dat win include
   ```
   `pline` 지문인지, `yn`/메뉴 질문인지, 조합 문자열의 일부인지에 따라 문체·존댓말이 달라질 수 있다. ([TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md) §4.2·**기존 번역 다듬기 원칙**)
3. **`ko_manual.po`만 수정** — 원칙·용어는 가이드를 따르고, **`%` 서식·`%n$s` 위치·조사 마커 `{을/를}` 등은 절대 깨지 않게** 한다.
4. **`cd po && make compile`** → 필요 시 루트에서 **`make all`** 로 `nhdat`에 반영.
5. **게임 내 확인 (필수)** — 같은 문자열이라도 출력 위치가 다르면 어색할 수 있으므로, 고친 문구가 나오는 동작을 **직접 재현**한다 (메시지 영역 한 줄·두 줄로 읽히는지, 상단/하단 로그 흐름과 어울리는지).
6. **자동 보조 점검** — `./po/translate-tool.sh postpos-check` 등 ([translate-tool help](./translate-tool.sh)).
7. **PR 전** — `./scripts/translation-preflight.sh`.

#### 다듬기 작업 체크리스트 (기계 검사 + 사람 검사)

| 구분 | 확인 내용 |
|------|-----------|
| 형식 | `make translation-ci` 통과, `%` 개수·순서 유지 |
| 문체 | 안내/지문/질문/대화 구분이 가이드와 맞는지 ([TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md) §4.2) |
| 출력감 | 실제 플레이에서 **한 줄로 읽었을 때** 자연스러운지 (어색한 한자어 나열·영어식 어순 지양) |
| 조사 | `{은/는}` 등 치환 후 실제 몬스터·아이템 이름이 들어가도 읽히는지 |
| 길이 | 좁은 폭·메시지 줄 수 제한에서 잘리거나 과하게 줄 바뀌지 않는지 |
| 회귀 | 같은 `msgid`가 다른 코드 경로에서도 쓰이면 **가장 까다로운 경로**까지 확인 |

#### 조합 메시지 추가 체크리스트 (§2.D에서 조각·`enl_msg` 건드릴 때)

상세 설명·패턴 표는 **[TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md) §7.4** 를 본다. 요약만 적어 둔다.

| 단계 | 할 일 |
|------|--------|
| 1. 용례 | `rg -n 'msgid|enl_msg|Sprintf.*_\(' src` 로 **포맷 + 인자** 확인 |
| 2. 시뮬 | 조각 `msgstr`을 넣어 **게임에 나올 한 줄**을 분기별로 손으로 작성 |
| 3. 충돌 | 동일 영문·다른 조합이면 `msgctxt` 분리 또는 포맷 `%n$s` 재배치 (소스 수정 포함) |
| 4. 주석 | `ko_manual.po`에 `# [조합]` / `# [조합 조각]` + 소스 줄 + 시뮬 2~4줄 + 혼동 금지 |
| 5. 검증 | `msgfmt -c` → 가능하면 인게임 → `translation-preflight.sh` |

**대표 사례** (파일 내 주석과 동기화 유지):

- `trap.c` — `"%s %s in a pile of soil below you."` + `There is` / `You discover` / `a trigger`
- `trap.c` / `eat.c` — `disarm`: `trap_action`(해제**하기**) vs `bear_trap_eat`(해제**하지 못하고 삼켰다**)
- `insight.c` — `enl_msg` + ` %1$s%3$s%2$s%4$s.` + `You regenerate` / `You cause` / `You aggravate`

---

## 3. PR / 커밋 전에 한 번에

저장소 루트에서:

```bash
./scripts/translation-preflight.sh
```

이 스크립트는 다음을 순서대로 수행한다.

1. `cd po && make translation-ci` — `ko_manual.po` / 병합본 `msgfmt -c`로 **형식 오류** 조기 차단, 통계 출력.
2. `scripts/check-i18n-wrapping.sh` — 플레이어 메시지에 `_()` 누락이 없는지 검사.
3. `scripts/check-locale-dat-sync.sh` — `dat/locale/ko/` 도움말·TXT가 영어 `dat/`와 얼마나 어긋났는지 **경고 목록** 출력 (기본 exit 0; `--strict`면 HARD 이슈 시 실패).

CI가 없을 때는 이 한 줄이 **최소 품질 게이트** 역할을 한다. locale TXT 동기화는 자동 번역이 아니라 **점검 → 수동 반영** 워크플로(§2.E)를 따른다.

---

## 2.E. `dat/locale/ko/` 도움말·TXT 동기화 (PO 밖)

`help`, `opthelp`, `history`, `rumors.*` 등은 **gettext PO가 아니라 파일 교체**로 한국어를 제공한다. 업스트림에서 `dat/`만 바뀌고 `dat/locale/ko/`를 안 고치면, 게임은 옛 한국어(또는 누락된 옵션 설명)를 계속 보여 준다.

### 언제 돌리나

- `upstream/NetHack-5.0` 머지 직후
- `dat/help`, `dat/opthelp`, `dat/*.txt` 등을 건드린 PR 전·후

### 점검

```bash
./scripts/check-locale-dat-sync.sh          # 목록만 (권장)
./scripts/check-locale-dat-sync.sh --strict # HARD(옵션 누락 등) 있으면 exit 1
./scripts/check-locale-lua-sync.sh        # Lua 짝 (별도)
python3 scripts/report-locale-ko-coverage.py  # KO 파일 안 영어 잔존 휴리스틱
```

**HARD** — 반드시 손댈 것 (예: `opthelp` 옵션 키 누락, `cmdhelp` `&?` 블록 수 불일치).  
**SOFT** — 영어 쪽이 더 최근 커밋, 줄 수 차이 큼 → `diff`로 확인 후 필요 시 반영.

### 반영 절차 (자동 merge 아님)

1. `git diff upstream/NetHack-5.0 -- dat/opthelp dat/history …` 로 **바뀐 파일** 확인.
2. `diff -u dat/opthelp dat/locale/ko/opthelp` — 변경 **의미 단위**(옵션 한 덩어리, 문단, 신탁 블록) 파악.
3. `dat/locale/ko/` 편집 — **영어 한 줄 = 한국어 한 줄**로 맞추지 말고, 같은 화면에서 읽히게 줄 재배치 ([TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md) §12).
4. 게임 `?` 메뉴에서 해당 항목 확인.
5. `./scripts/check-locale-dat-sync.sh` 재실행.

### 파일 유형별 기준

| 유형 | 동기화 기준 | 번역 단위 |
|------|-------------|-----------|
| `opthelp`, `optmenu` | 옵션 **키** 집합 일치 | 옵션 설명 통째로 → 열 맞춰 1~2줄 |
| `cmdhelp` | `&?` / `&:` / `&.` 개수 | 조건 블록 + 설명 줄 |
| `oracles.txt` | `-----` 블록 수 | 블록(신탁) 단위 |
| `history`, `help` | 버전·줄 수·diff | 문단 단위 |
| `rumors.*`, `epitaph.txt` | 항목 줄 수(근사) | 항목 단위 |

완전 자동 동기화는 하지 않는다. 스크립트는 **백로그 우선순위**를 정하고, 번역은 사람(또는 에이전트)이 의미 단위로 한다.

---

## 4. 자주 쓰는 명령 (치트시트)

| 목적 | 명령 |
|------|------|
| 병합 + mo + dat 복사 | `cd po && make compile` |
| 통계 | `cd po && make stats` 또는 `./po/translate-tool.sh stats` |
| 미번역/퍼지 목록 | `cd po && make untranslated` / `make fuzzy` |
| 수동 점검 (조사·접두어 등) | `./po/translate-tool.sh postpos-check` 등 ( `./po/translate-tool.sh help` ) |
| 소스에서 문자열 용례 검색 | 저장소 루트에서 `rg '패턴' src dat win` |
| PO만 빠르게 유효성 | `cd po && make translation-ci` |
| 래핑만 | `./scripts/check-i18n-wrapping.sh` |
| locale TXT 동기화 점검 | `./scripts/check-locale-dat-sync.sh` |
| locale Lua 짝 점검 | `./scripts/check-locale-lua-sync.sh` |
| locale Lua **심층** (로직·메시지) | `python3 scripts/audit-locale-lua-structure.py` |

---

## 5. 막혔을 때

- **`msgfmt`가 실패** — 대부분 `msgid`/`msgstr`의 `%` 서식 개수 불일치, 따옴표 누락. `ko_manual.po`에서 해당 msgid 주변을 수정.
- **퍼지(`#, fuzzy`)** — `msgmerge`가 추측한 번역. 문맥에 맞게 고친 뒤 `fuzzy` 표시를 제거(가이드 참고).
- **Windows** — Git Bash 또는 MSYS2 UCRT64에서 위 `make`/`bash` 경로를 그대로 쓰면 된다. PowerShell만으로는 gettext가 없을 수 있다.

---

## 6. 문서·스크립트 맵 (갱신 시 이 파일도)

- [README.md](README.md) — 이 프로세스의 짧은 요약 + `translate-tool` 요약
- [TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md) — 문장 규칙
- [I18N_SYSTEM.md](I18N_SYSTEM.md) — `_()` / `mo_reader` / 조사 API
- `po/translate-tool.sh` — 검색·CSV·검증 보조
- `scripts/apply_ko_translations.py` — TR + remainder → `ko_manual.po`; 빈 칸만 기본. 정책 변경 일괄 반영: `--sync-all-in-catalog`
- `po/build_remainder_translations.py` — remainder JSON; **내부 진단·시스템 메시지는 영어 msgid 유지**, 플레이어 대면만 한국어(FULL/짧은 고유명·퀘스트 질문 등). `--refresh-all`
- `po/remainder_quality_patch.json` — 수동 덮어쓰기(선택, 보통 비움)
- `po/sync_new_msgids_to_manual.py` — 로컬 `ko.po`의 신규 블록을 `ko_manual.po`로 스텁 복사
- `po/extract_lua_strings.py` — `dat/*.lua`에서 POT 보조 추출(선택)
- `scripts/translation-preflight.sh` — PR 전 통합 검사 (PO + 래핑 + locale TXT 점검)
- `scripts/check-locale-dat-sync.sh` — `dat/locale/ko/` 도움말·TXT 동기화 백로그
- `scripts/check-locale-lua-sync.sh` — `dat/locale/ko/*.lua` 줄 수·API 패턴
- `scripts/report-locale-ko-coverage.py` — KO 경로 영어 잔존 휴리스틱

프로세스를 바꾸면(새 Makefile 타깃, 새 스크립트) **이 문서와 `po/README.md`, `AGENTS.md`의 링크**를 함께 맞추는 것이 좋다.
