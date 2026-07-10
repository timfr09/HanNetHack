# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview
HanNetHack is a Korean-localized fork of NetHack 5.0 (default branch `HanNetHack-5.0`). It's a C-based roguelike game with an in-tree message catalog (`src/mo_reader.c` reads a plain GNU gettext `.mo` bundled inside nhdat), GNU gettext *tools* for maintaining `po/*.po`, and a Korean postposition engine.

### Build
**환경별 요약:** `doc/build-environments.md` — Linux·Windows(MinGW)·MSVC 표와 실패 원인
(`src/GNUmakefile` 우선순위, `GNUmakefile.depend` 이름). 이론적 HOST/TARGET 분리는
루트 `Cross-compiling` Part B 참고.

**Shell (`*.sh`):** LF 줄바꿈 유지(WSL/Linux에서 `sh` 실패 방지); `.gitattributes`·세부 확인은 같은 문서.

**Linux / WSL (권장 일괄):**
```bash
sh scripts/build-linux-unix.sh
```

**수동 (Unix):**
```bash
cd sys/unix && sh setup.sh hints/linux.500 && cd ../..
make fetch-lua   # downloads Lua 5.4.8 source (only needed once)
make all         # compiles everything; do NOT use -j (parallel make can race on Lua)
make install     # installs to ~/nh/install/
```

**Windows MinGW (MSYS2):** `sh scripts/build-windows-mingw.sh` (gcc + GNU make).  
**Windows MSVC:** `sys/windows/build-hannethack.txt` / `nhsetup.bat` + `nmake`.

### Running the Game
```bash
HACKDIR=~/nh/install/games/lib/nethackdir TERM=xterm-256color ./src/nethack
```
Korean is the default language. Config goes in `~/.nethackrc`.

**Cloud VM note:** `sys/unix/setup.sh hints/linux.500` sets `HACKDIR` to `$(repo root)/playground`,
so after `make install` the runnable tree is `/workspace/playground`, not `~/nh/...`. Launch with:
```bash
HACKDIR=/workspace/playground TERM=xterm-256color ./src/nethack
```
This is a TTY (ncurses) game. For a GUI-terminal demo on the XFCE desktop (`DISPLAY=:1`,
only `xfce4-terminal` is installed), the terminal's default foreground can equal the background
(text renders invisible). Force colors first, e.g. prepend
`printf '\033]10;#e6e6e6\007\033]11;#101010\007';` before the `nethack` command. Drive keys with
`xdotool` targeting the *focused* window (`windowactivate --sync` then `key`), not `--window`.

### Translation Workflow
- **Only `po/ko_manual.po` is committed.** It is the canonical source of Korean translations.
- `po/ko.po` is a local cache rebuilt by `make update-po` from `nethack.pot`; it is gitignored and never edited by hand. `make compile` works without it (uses `ko_manual.po` directly).
- `cd po && make compile` to merge + compile translations.
- `cd po && make stats` to see translation statistics.
- **`./scripts/translation-preflight.sh`** (from repo root) runs `po`’s `make translation-ci` (msgfmt checks), `scripts/check-i18n-wrapping.sh`, and **`scripts/check-locale-dat-sync.sh`** (warn-only backlog for `dat/locale/ko/` help·TXT vs `dat/`). Use before PRs that touch `po` or translatable source. After upstream merges touching `dat/help`, `dat/opthelp`, etc., also run `./scripts/check-locale-dat-sync.sh --strict` and follow `po/TRANSLATION_PROCESS.md` §2.E.
- `cd po && make translation-ci` alone validates `ko_manual.po` + merged PO without the wrapping script.
- See `po/TRANSLATION_PROCESS.md` for the full operational workflow, and `po/TRANSLATION_GUIDE_KO.md` for rules and tone.

### Documentation map (for humans / agents)
| Doc | Audience |
|-----|----------|
| `README.md` | Visitors — what the fork is, upstream merges, issues; Windows ZIP (KO); overview + build & i18n notes |
| `po/README.md` | Translators — short workflow |
| `po/TRANSLATION_PROCESS.md` | Translators & maintainers — when to run `pot` / `safe-update` / `translation-ci` |
| `po/TRANSLATION_GUIDE_KO.md` | Translators — rules, tone, particles |
| `po/I18N_SYSTEM.md` | Developers — architecture & APIs |
| `doc/i18n-upstream-merge.md` | Maintainers — merging upstream NetHack into this fork |
| `doc/build-environments.md` | Developers — Linux vs Windows MinGW vs MSVC; GNUmakefile pitfalls |

### Lint / Test
There is no full test suite. For i18n changes, run **`./scripts/translation-preflight.sh`** (or at least `cd po && make translation-ci` plus `scripts/check-i18n-wrapping.sh`). `make all` is the main compile check (treat compiler warnings as lint).
