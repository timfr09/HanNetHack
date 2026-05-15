# HanNetHack 빌드 환경 정리

`Cross-compiling`(저장소 루트) Part A/B는 **HOST ≠ TARGET** 일 때(예: Linux에서 MS-DOS용
도구를 교차 컴파일) makedefs/dlb 등을 HOST 네이티브로 두고 게임만 크로스 컴파일하는
이론입니다. 이 문서는 그와 구분해, **HOST = TARGET** 인 일상적인 빌드 경로를 표로
고정합니다.

| 환경 | 설명 | 재현 방법 |
|------|------|-----------|
| **Linux / WSL (Unix)** | `hints/linux.500` + 상위 `Makefile` | `scripts/build-linux-unix.sh` |
| **Windows MinGW-w64** | `sys/windows/GNUmakefile`, gcc, GNU make (MSYS2 권장) | `scripts/build-windows-mingw.sh` |
| **Windows MSVC** | `Makefile.nmake`, `nmake` | `sys/windows/nhsetup.bat` 후 `src`에서 `nmake`(또는 `nmake /f Makefile.win`). **Visual Studio 또는 Build Tools for Visual Studio** 필요. 상세: `sys/windows/build-hannethack.txt`, `build-nmake.txt` |

## Linux / WSL에서 흔한 실패: `src/GNUmakefile`

GNU make는 `src` 디렉터리에서 **`GNUmakefile`** 이름을 **`Makefile`보다 우선**합니다.
Windows MinGW 빌드가 남긴 **`src/GNUmakefile`(gitignore)** 이 있으면, WSL에서
`setup.sh hints/linux.500` 후 `make all`을 해도 **Unix `Makefile`이 아니라 Win32 규칙**이
잡혀 `io.h` 등으로 실패합니다.

**대응:** `scripts/build-linux-unix.sh`가 빌드 전에 `src/GNUmakefile` 및 MinGW 전용
`src/GNUmakefile.depend` 를 제거합니다.

## Windows MinGW에서 흔한 실패: `make -f GNUmakefile.win` + depend

`-f GNUmakefile.win` 로 빌드해도, 파일 끝의 `-include GNUmakefile.depend` 때문에
**같은 디렉터리에 `GNUmakefile.depend`** 가 있어야 합니다. `nhsetup.bat` 기본값이
`GNUmakefile.depend.win` 만 복사하는 경우, 의존 파일 이름이 맞지 않을 수 있습니다.
`scripts/build-windows-mingw.sh`는 원본을 `src/GNUmakefile.depend`로 맞춥니다.

## MSYS2 최소 패키지 (MinGW 경로)

`sys/windows/build-msys2.txt` 참고. 예(UCRT64 셸):

```bash
pacman -S mingw-w64-ucrt-x86_64-gcc git make curl tar gettext
```

`gettext`는 `po/ko_manual.po` → `dat/locale/ko/nethack.mo` 생성에 사용합니다.

## CI

GitHub Actions `.github/workflows/build.yml`은 Linux(Unix 힌트)와 Windows(MSVC+nmake)
를 검증합니다. MinGW는 로컬/MSYS2에서 위 스크립트로 확인합니다.
