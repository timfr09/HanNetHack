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

---

## 3. PR / 커밋 전에 한 번에

저장소 루트에서:

```bash
./scripts/translation-preflight.sh
```

이 스크립트는 다음을 순서대로 수행한다.

1. `cd po && make translation-ci` — `ko_manual.po` / 병합본 `msgfmt -c`로 **형식 오류** 조기 차단, 통계 출력.
2. `scripts/check-i18n-wrapping.sh` — 플레이어 메시지에 `_()` 누락이 없는지 검사.

CI가 없을 때는 이 한 줄이 **최소 품질 게이트** 역할을 한다.

---

## 4. 자주 쓰는 명령 (치트시트)

| 목적 | 명령 |
|------|------|
| 병합 + mo + dat 복사 | `cd po && make compile` |
| 통계 | `cd po && make stats` 또는 `./po/translate-tool.sh stats` |
| 미번역/퍼지 목록 | `cd po && make untranslated` / `make fuzzy` |
| 수동 점검 (조사·접두어 등) | `./po/translate-tool.sh postpos-check` 등 ( `./po/translate-tool.sh help` ) |
| PO만 빠르게 유효성 | `cd po && make translation-ci` |
| 래핑만 | `./scripts/check-i18n-wrapping.sh` |

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
- `scripts/translation-preflight.sh` — PR 전 통합 검사
- `scripts/i18n-check.sh` — 업스트림 병합 후 diff 스타일 점검(선택)

프로세스를 바꾸면(새 Makefile 타깃, 새 스크립트) **이 문서와 `po/README.md`, `AGENTS.md`의 링크**를 함께 맞추는 것이 좋다.
