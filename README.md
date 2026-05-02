# HanNetHack — Korean NetHack

![Version](https://img.shields.io/badge/version-3.7.0--ko.4-blue)
![License](https://img.shields.io/badge/license-NGPL-green)
![Translation](https://img.shields.io/badge/translation-WIP-yellow)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)

**HanNetHack**은 NetHack 3.7을 바탕으로 한 **비공식 한국어 로컬라이즈 포크**입니다. 게임 안의 영문 메시지는 GNU gettext 형식의 **`nethack.mo`** 번역 카탈로그로 빌드되어 `nhdat` 데이터 묶음 안에 포함되고, 실행 시에는 이 포크에 포함된 자체 리더(`src/mo_reader.c`)가 이를 읽습니다. (`libintl` 동적 라이브러리를 런타임에 의존하지 않습니다.)

번역을 손으로 고치는 저장소 기준 파일은 **`po/ko_manual.po`** 하나입니다. `ko.po`는 로컬에서 `make update-po` 등으로 만들어 두는 **선택적 캐시**(자동 추출 문자열용)이며 git에는 올리지 않습니다. 한국어 도움말·루머·Lua 등은 `dat/locale/ko/` 아래 두고 `dlb_fopen()`이 언어별 경로를 우선합니다.

원본 [NetHack](https://github.com/NetHack/NetHack) 저장소의 변경은 가능할 때마다 이쪽 브랜치로 가져와 병합합니다.

---

**English:** A personal, unofficial Korean localization of NetHack 3.7 for Linux and Windows. Message catalogs ship as `.mo` inside `nhdat`; runtime lookup uses the in-tree reader above, not GNU libintl.

> **Note**: This is an unofficial fan translation project, not affiliated with the NetHack DevTeam.

> **Reporting translation errors**: Translations are still being polished. If you spot a mistake or awkward phrasing, please open a ticket on [Issues](https://github.com/timfr09/HanNetHack/issues).

![HanNetHack on Windows](doc/screenshot-win.png)

---

## Features

### Korean Translation
- 대규모 게임 메시지 번역 (계속 다듬는 중; 통계는 `cd po && make stats`)
- Dynamic postposition system for natural Korean grammar (`{은/는}`, `{이/가}`, `{을/를}`, `{과/와}`, `{으로/로}`)
- Speech-style distinction (polite / casual / semi-polite) following the in-game speaker
- Consistent terminology across all game messages
- Word order optimized for natural Korean using positional format specifiers (`%1$s`, `%2$s`, …)
- Context-aware translations using `C_()` (`pgettext`) for shared strings with different meanings
- Encyclopedia (data.base) Korean translation

### Enhanced Display
- Korean full-width symbol set (`symset:Korean`)
- Emoji symbol set (`symset:Emoji`)
- CJK / UTF-8 character width handling for both TTY and Windows GUI
- Localized character-creation dialog on the Windows GUI build (job/race names shown in Korean)

---

## Installation

### Pre-built Binaries

The easiest way to try HanNetHack is to grab a pre-built release from the
[Releases](https://github.com/timfr09/HanNetHack/releases) page. Windows portable
ZIPs are produced by the GitHub Actions release workflow.

### Build from Source — Linux

```bash
# Clone the repository
git clone https://github.com/timfr09/HanNetHack.git
cd HanNetHack

cd sys/unix && sh setup.sh hints/linux.370 && cd ../..
make fetch-lua          # one-time: download Lua 5.4.8 source
make all                # do NOT use -j (Lua build can race)
make install            # installs to ~/nh/install/

HACKDIR=~/nh/install/games/lib/nethackdir TERM=xterm-256color ./src/nethack
```

### Build from Source — Windows (Visual Studio)

The Windows GUI build (`NetHackW.exe`, GDI tile renderer) and the Windows
console build (`NetHack.exe`) are both fully supported. Korean text in messages,
inventory, and the player-selection dialog all renders natively.

```cmd
:: From a Developer Command Prompt for VS 2022 at the repo root:
sys\windows\fetch.cmd lua
sys\windows\fetch.cmd pdcursesmod

:: Optional: gettext tools under lib\gettext\bin — only if you edit po/*.po
:: or run `nmake package` to rebuild the .mo catalog inside nhdat.
::   sys\windows\setup-gettext.cmd

:: Build (or open sys\windows\vs\NetHack.sln in Visual Studio)
msbuild sys\windows\vs\NetHack.sln /p:Configuration=Release /p:Platform=x64 /m

:: Install into a runnable directory
sys\windows\install.cmd
```

The result lives in `install\HanNetHack\` and can be moved anywhere; double-click
`NetHackW.exe` for the GUI version.  The packaged/install output includes
English/Korean document pairs for `Guidebook` and `NetHack` docs
(`Guidebook.txt` + `Guidebook.ko.txt`, `NetHack.txt` + `NetHack.ko.txt`),
plus `recover.txt` + `recover.ko.txt`.

See [`sys/windows/build-hannethack.txt`](sys/windows/build-hannethack.txt) for
prerequisites, troubleshooting, and Visual Studio setup details.

---

## Configuration

### Language

The game defaults to Korean. To change it, edit `~/.nethackrc` (or
`%USERPROFILE%\NetHack\.nethackrc` on Windows):

```
OPTIONS=language:ko    # Korean (default)
OPTIONS=language:en    # English
```

### Symbol Sets

```
OPTIONS=symset:Korean                    # Korean full-width symbols
OPTIONS=symset:Emoji                     # Emoji symbols
OPTIONS=symset:IBMgraphics_langstripped  # ASCII
```

---

## Translation Details

### Postposition System

Korean postpositions depend on whether the preceding syllable ends in a
consonant. HanNetHack picks the correct form at runtime:

| Pattern    | Usage             | Example                        |
|------------|-------------------|--------------------------------|
| `{은/는}`  | Topic marker      | 드래곤**은** / 개미**는**       |
| `{이/가}`  | Subject marker    | 검**이** / 도끼**가**          |
| `{을/를}`  | Object marker     | 검**을** / 도끼**를**          |
| `{과/와}`  | "and / with"      | 검**과** / 방패**와**          |
| `{으로/로}`| Direction / means | 북쪽**으로** / 아래**로**       |

### Speech Styles

| Context         | Style        | Example                          |
|-----------------|--------------|----------------------------------|
| User prompts    | Polite       | "무엇을 버리시겠습니까?"         |
| Game narration  | Casual       | "배가 고프다."                   |
| Shopkeeper      | Semi-polite  | "계산해 주세요."                 |
| Other NPCs      | Casual       | "안녕."                          |

---

## Contributing

### Translation Improvements

1. Edit **`po/ko_manual.po`** only (the canonical committed source).
2. Build the catalog: `cd po && make compile` (writes `dat/locale/ko/nethack.mo`; optional local `ko.po` from `make update-po` acts as a merge fallback).
3. Rebuild the game so `nhdat` picks up the new catalog: from the repo root, `make all` (after the usual `sys/unix` setup on Linux).
4. Play-test and open a pull request against **this fork** (`timfr09/HanNetHack`).

Quick reference: [`po/README.md`](po/README.md). Detailed Korean conventions: [`po/TRANSLATION_GUIDE_KO.md`](po/TRANSLATION_GUIDE_KO.md). Maintainer-oriented upstream merge notes: [`doc/i18n-upstream-merge.md`](doc/i18n-upstream-merge.md).

### Reporting Issues

Please report translation errors or suggestions on
[GitHub Issues](https://github.com/timfr09/HanNetHack/issues).

---

## Versioning

HanNetHack uses semantic versioning with a Korean-translation suffix:

```
v3.7.0-ko.4
  │    │  └── Korean translation iteration
  │    └───── Based on NetHack 3.7.0
  └────────── Major version
```

---

## License

NetHack General Public License (NGPL). See `dat/license` for details.

---

## Credits

- **Original NetHack**: [NetHack DevTeam](https://github.com/NetHack/NetHack)
- **Korean Translation**: HanNetHack Project

---

## Links

- [Original NetHack](https://nethack.org/)
- [NetHack on GitHub](https://github.com/NetHack/NetHack)
- [HanNetHack Releases](https://github.com/timfr09/HanNetHack/releases)
