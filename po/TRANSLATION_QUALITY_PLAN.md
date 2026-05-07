# 번역 품질 개선 실행 계획

## 목표
- 게임 내 한국어 문구의 **일관성, 자연스러움, 가독성**을 높인다.
- 릴리스 전 점검을 자동화해 회귀(오역/줄바꿈 깨짐/톤 불일치)를 줄인다.

## 범위
- 기준 파일: `po/ko_manual.po`
- 관련 점검: `po/Makefile`의 `translation-ci`, `scripts/check-i18n-wrapping.sh`
- 참고 문서: `po/TRANSLATION_GUIDE_KO.md`, `po/TRANSLATION_PROCESS.md`

## 실행 단계

### 1) 기준선 측정 (Baseline)
1. `cd po && make stats`로 현재 번역 통계(번역률, fuzzy, untranslated) 기록
2. `cd po && make translation-ci` 실행 결과를 저장해 현재 경고/오류 유형 분류
3. 자주 깨지는 줄바꿈 패턴을 `scripts/check-i18n-wrapping.sh` 결과 기준으로 목록화

### 2) 용어/톤 일관성 정비
1. `po/TRANSLATION_GUIDE_KO.md`에 핵심 용어 50~100개를 우선 정리
2. `ko_manual.po`에서 동일 source string의 번역 변형을 찾아 통일
3. 존댓말/평서체/명령형 사용 기준을 메시지 유형별(안내/오류/튜토리얼/전투)로 명시

### 3) 조사(은/는/이/가) 품질 강화
1. 조사 처리 함수가 적용되는 메시지와 미적용 메시지를 분리해 목록화
2. 미적용 메시지 중 플레이 체감이 큰 문구부터 우선 보정
3. 고유명사/영문 혼합 단어/숫자 접미 상황을 대표 케이스로 회귀 점검 세트 작성

### 4) 고위험 메시지 우선 검수
1. 전투 로그, 상태 이상, 인벤토리, 튜토리얼 문구를 1차 집중 검수
2. 길이 제한(터미널 폭) 민감 문자열은 축약안/대체안 함께 기록
3. 환각(hallucination)·디버그/진단 문자열은 영어 유지/번역 원칙을 문서화

### 5) PR 전 품질 게이트 고정
1. `./scripts/translation-preflight.sh`를 번역 PR 필수 체크로 명시
2. 실패 유형별 수정 가이드를 `po/README.md`에 링크
3. 병합 전 체크리스트(용어 통일, wrapping, msgfmt, 플레이 로그 샘플 검토) 도입

## 작업 분할 제안
- 배치 A: 용어집/톤 가이드 보강
- 배치 B: 조사 품질 및 자동 점검 강화
- 배치 C: 고위험 영역(전투/튜토리얼) 집중 검수

## 완료 기준 (Definition of Done)
- `ko_manual.po` 기준 untranslated/fuzzy 감소 추세 확인
- `translation-ci`와 wrapping 점검 연속 통과
- 대표 플레이 로그 3종(초반/전투/튜토리얼)에서 어색한 조사/톤 이슈 미발견
