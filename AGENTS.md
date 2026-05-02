# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview
HanNetHack is a Korean-localized fork of NetHack 3.7. It's a C-based roguelike game with an in-tree message catalog (`src/mo_reader.c` reads a plain GNU gettext `.mo` bundled inside nhdat), GNU gettext *tools* for maintaining `po/*.po`, and a Korean postposition engine.

### Build
```bash
cd sys/unix && sh setup.sh hints/linux.370 && cd ../..
make fetch-lua   # downloads Lua 5.4.8 source (only needed once)
make all         # compiles everything; do NOT use -j (parallel make can race on Lua)
make install     # installs to ~/nh/install/
```

### Known Build Fix (upstream bug)
Two build errors exist on the current branch:
- `src/insight.c` calls `ko_process_string` without `#include "ko_postpos.h"` — add the include after `#include "hack.h"`.
- `src/nhlobj.c` calls `get_table_objtype` / `get_table_objclass` (static in `sp_lev.c`) without declarations — add `extern` declarations to `include/sp_lev.h`.

### Running the Game
```bash
HACKDIR=~/nh/install/games/lib/nethackdir TERM=xterm-256color ./src/nethack
```
Korean is the default language. Config goes in `~/.nethackrc`.

### Translation Workflow
- **Edit `po/ko_manual.po`** (never `ko.po` directly — it gets overwritten by `make update-po`).
- `cd po && make compile` to merge + compile translations.
- `cd po && make stats` to see translation statistics.
- `scripts/check-i18n-wrapping.sh` checks for unwrapped `_()` strings in source.
- See `po/TRANSLATION_GUIDE_KO.md` for full translation rules and conventions.

### Lint / Test
There is no dedicated test suite or linter beyond `make all` (compiler warnings as lint) and the `scripts/check-i18n-wrapping.sh` script.
