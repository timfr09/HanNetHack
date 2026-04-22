# HanNetHack — Korean NetHack

![Version](https://img.shields.io/badge/version-3.7.0--ko.4-blue)
![License](https://img.shields.io/badge/license-NGPL-green)
![Translation](https://img.shields.io/badge/translation-WIP-yellow)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)

A personal Korean localization of NetHack 3.7.

> **Note**: This is an unofficial fan translation project, not affiliated with the NetHack DevTeam.

> **Reporting translation errors**: Translations are still being polished. If you spot a mistake or awkward phrasing, please open a ticket on [Issues](https://github.com/timfr09/HanNetHack/issues).

![HanNetHack on Windows](doc/screenshot-win.png)

---

## Features

### Korean Translation
- 11,000+ messages translated (work in progress)
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
:: or run `nmake package` to rebuild the .mox catalog inside nhdat.
::   sys\windows\setup-gettext.cmd

:: Build (or open sys\windows\vs\NetHack.sln in Visual Studio)
msbuild sys\windows\vs\NetHack.sln /p:Configuration=Release /p:Platform=x64 /m

:: Install into a runnable directory
sys\windows\install.cmd
```

The result lives in `install\HanNetHack\` and can be moved anywhere; double-click
`NetHackW.exe` for the GUI version.  Both `Guidebook.txt` (English) and
`Guidebook.ko.txt` (Korean) are included in the packaged/install output.

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

1. Edit `po/ko_manual.po` (**not** `ko.po` — that file is auto-generated and
   gets overwritten by `make update-po`).
2. Compile the merged catalog: `cd po && make compile`.
3. Run the game and verify the change in context.
4. Submit a pull request against this fork.

See [`po/README.md`](po/README.md) and `po/TRANSLATION_GUIDE_KO.md` for the
full translation workflow and conventions.

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
