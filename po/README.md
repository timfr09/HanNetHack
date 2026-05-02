# NetHack 한국어 번역 가이드

## 개요

이 디렉터리는 HanNetHack의 gettext 번역 소스와 빌드 규칙을 둡니다. 실무 규칙·조사·문체의 상세는 **[TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md)** 를 보고, 시스템 구조 참고는 **[I18N_SYSTEM.md](I18N_SYSTEM.md)** 를 쓰면 됩니다.

## 파일 구조

```
po/
├── ko_manual.po       # ⭐ 수동 번역 (유일한 편집 대상, 저장소에 커밋됨)
├── ko.po              # 로컬 캐시 (update-po가 생성; 저장소에 없음)
├── ko_merged.po       # 병합 결과 (자동 생성)
├── ko.mo              # 컴파일된 바이너리 (자동 생성)
├── nethack.pot        # 원문 템플릿 (자동 생성)
├── Makefile           # 번역 빌드 규칙
└── README.md          # 이 문서
```

## ⚠️ 중요: 번역 파일 정책

### 편집 대상은 오직 `ko_manual.po`

| 파일 | 역할 | 편집 | 저장소 커밋 |
|------|------|------|-------------|
| `ko_manual.po` | 한국어 번역의 단일 소스 | ⭐ **O** | **O** |
| `ko.po` | `update-po`가 POT에서 만드는 로컬 캐시 | ❌ X | X (gitignored) |
| `ko_merged.po` | 병합 결과 | ❌ X | X (gitignored) |

`ko.po`는 빌드에 꼭 필요하지 않습니다 — `make compile`은 `ko_manual.po`만으로도 정상 동작합니다. `update-po`를 실행해 로컬에 ko.po가 존재하면, 거기에 들어 있는 자동 추출 엔트리가 `ko_manual.po`가 아직 번역하지 않은 항목의 fallback으로 사용됩니다.

### 병합 우선순위

```
ko_manual.po (우선) + ko.po (선택, 로컬 캐시) → ko_merged.po → ko.mo
```

동일한 msgid가 있으면 `ko_manual.po`의 번역이 사용됩니다.

---

## 번역 워크플로우

### 일반 번역 작업 (권장)

```bash
cd po

# 1. ko_manual.po 편집 (수동 번역 추가/수정)
vi ko_manual.po

# 2. 병합 + 컴파일 → ../dat/locale/ko/nethack.mo 로 복사됨
make compile

# 3. 게임 전체 다시 빌드(nhdat에 .mo 반영)
cd .. && make all
```

### 소스에서 새 문자열 추출할 때

```bash
cd po

# 1. POT 템플릿 생성
make pot

# 2. 안전하게 ko.po 업데이트 (백업 자동 생성)
make safe-update

# 3. 새 문자열을 ko_manual.po에 번역 추가
vi ko_manual.po

# 4. 병합 + 컴파일
make compile
```

### 번역 통계 확인

```bash
make stats
```

## 번역 규칙 (요약)

조사 마커 `{은/는}`, `{이/가}`, `{을/를}` 등과 문체·용어 통일·포맷 문자열 규칙은 모두 **[TRANSLATION_GUIDE_KO.md](TRANSLATION_GUIDE_KO.md)** 에 정리되어 있습니다. 이 README에서는 워크플로우만 다룹니다.

## 번역 관리 도구

`translate-tool.sh`는 번역 작업을 도와주는 스크립트입니다:

```bash
# 통계 보기
./translate-tool.sh stats

# 문자열 검색
./translate-tool.sh search "You hit"

# 미번역 목록
./translate-tool.sh untranslated

# 검토 필요 목록
./translate-tool.sh fuzzy

# 조사 패턴 검증
./translate-tool.sh postpos-check

# CSV로 내보내기 (스프레드시트 검토용)
./translate-tool.sh export-csv

# 번역 유효성 검사
./translate-tool.sh validate

# 백업 생성
./translate-tool.sh backup
```

## 기여 방법

1. `ko_manual.po` 만 편집합니다 (`ko.po`는 로컬 캐시).
2. `make compile` 후 저장소 루트에서 `make all` 로 전체 빌드·`nhdat` 반영.
3. `make stats` 로 통계 확인.
4. 이 포크(`timfr09/HanNetHack`)로 Pull Request.

## 테스트

개발 중 바이너리가 `./src/nethack` 인 경우:

```bash
cd ../..   # 저장소 루트
LANG=ko_KR.UTF-8 ./src/nethack
# 또는 심볼: LANG=ko_KR.UTF-8 ./src/nethack -symset:Korean
```

설치 경로(`make install`)로 실행할 때는 `HACKDIR` 등은 루트 [README.md](../README.md) 및 `AGENTS.md`를 참고합니다.

## 문의

[GitHub Issues](https://github.com/timfr09/HanNetHack/issues)
