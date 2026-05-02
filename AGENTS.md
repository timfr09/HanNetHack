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

### Running the Game
```bash
HACKDIR=~/nh/install/games/lib/nethackdir TERM=xterm-256color ./src/nethack
```
Korean is the default language. Config goes in `~/.nethackrc`.

### Translation Workflow
- **Only `po/ko_manual.po` is committed.** It is the canonical source of Korean translations.
- `po/ko.po` is a local cache rebuilt by `make update-po` from `nethack.pot`; it is gitignored and never edited by hand. `make compile` works without it (uses `ko_manual.po` directly).
- `cd po && make compile` to merge + compile translations.
- `cd po && make stats` to see translation statistics.
- `scripts/check-i18n-wrapping.sh` checks for unwrapped `_()` strings in source.
- See `po/TRANSLATION_GUIDE_KO.md` for full translation rules and conventions.

### Documentation map (for humans / agents)
| Doc | Audience |
|-----|----------|
| `README.md` | Visitors — what the fork is, upstream merges, issues; Windows ZIP (KO); overview + build & i18n notes |
| `po/README.md` | Translators — short workflow |
| `po/TRANSLATION_GUIDE_KO.md` | Translators — rules, tone, particles |
| `po/I18N_SYSTEM.md` | Developers — architecture & APIs |
| `doc/i18n-upstream-merge.md` | Maintainers — merging upstream NetHack into this fork |

### Lint / Test
There is no dedicated test suite or linter beyond `make all` (compiler warnings as lint) and the `scripts/check-i18n-wrapping.sh` script.
