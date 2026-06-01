#!/usr/bin/env python3
"""Audit dat/locale/ko vs dat/ for missing copies and English leftovers."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DAT = ROOT / "dat"
KO = DAT / "locale" / "ko"

# Known locale-replaceable paths (see po/I18N_SYSTEM.md, doc/i18n-upstream-merge.md)
EXPECTED_LOCALE = [
    "help",
    "hh",
    "cmdhelp",
    "keyhelp",
    "opthelp",
    "optmenu",
    "usagehlp",
    "wizhelp",
    "history",
    "bogusmon.txt",
    "engrave.txt",
    "epitaph.txt",
    "oracles.txt",
    "rumors.tru",
    "rumors.fal",
    "nhlib.lua",
    "nhcore.lua",
    "quest.lua",
    "themerms.lua",
    "air.lua",
    "earth.lua",
    "water.lua",
    "astral.lua",
    "minend-2.lua",
    "tut-1.lua",
    "tut-2.lua",
    "Arc-loca.lua",
    "data.base",
]

EN_WORD = re.compile(r"[A-Za-z]{4,}")
HANGUL = re.compile(r"[\uac00-\ud7a3]")
SKIP_LINE = re.compile(
    r"^\s*(--|#|function |local |if |then|else|end|return|require|\[)"
)


def is_mostly_english(s: str) -> bool:
    if HANGUL.search(s):
        return False
    if not EN_WORD.search(s):
        return False
    if s.startswith("#") or s.startswith("%"):
        return False
    # keep short tokens, file paths, keys
    if len(s) < 10:
        return False
    letters = sum(c.isalpha() for c in s)
    if letters < 8:
        return False
    return True


def scan_file(path: Path) -> list[tuple[int, str]]:
    hits: list[tuple[int, str]] = []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return hits
    for i, line in enumerate(text.splitlines(), 1):
        if SKIP_LINE.match(line):
            continue
        if path.suffix == ".lua":
            for m in re.finditer(r'"([^"\\]{6,})"', line):
                s = m.group(1)
                if is_mostly_english(s):
                    hits.append((i, s[:100]))
        else:
            stripped = line.strip()
            if stripped and is_mostly_english(stripped):
                hits.append((i, stripped[:100]))
    return hits


def compare_lua_msg_counts(en: Path, kr: Path) -> tuple[int, int]:
    pat = re.compile(r"\b(pline|verbalize|nh\.text)\s*\(")
    en_n = sum(1 for line in en.read_text(encoding="utf-8").splitlines() if pat.search(line))
    kr_n = sum(1 for line in kr.read_text(encoding="utf-8").splitlines() if pat.search(line))
    return en_n, kr_n


def main() -> int:
    missing: list[str] = []
    for name in EXPECTED_LOCALE:
        en = DAT / name
        if en.is_file() and not (KO / name).is_file():
            missing.append(name)

    lua_mismatch: list[str] = []
    for name in EXPECTED_LOCALE:
        if not name.endswith(".lua"):
            continue
        en, kr = DAT / name, KO / name
        if en.is_file() and kr.is_file():
            en_n, kr_n = compare_lua_msg_counts(en, kr)
            if en_n != kr_n:
                lua_mismatch.append(f"{name}: EN pline/text={en_n}, KO={kr_n}")

  # data.base: rough English line ratio in ko copy
    data_ko = KO / "data.base"
    data_en = DAT / "data.base"
    data_note = ""
    if data_ko.is_file() and data_en.is_file():
        ko_lines = data_ko.read_text(encoding="utf-8", errors="replace").splitlines()
        enish = sum(1 for ln in ko_lines if is_mostly_english(ln.strip()) and len(ln.strip()) > 20)
        data_note = f"data.base: ~{enish} mostly-English lines in ko copy (of {len(ko_lines)} lines)"

    print("=== dat/locale/ko audit (non-PO paths) ===\n")
    print(f"Expected locale files checked: {len(EXPECTED_LOCALE)}")
    print(f"Present under dat/locale/ko/: {sum(1 for n in EXPECTED_LOCALE if (KO/n).is_file())}")
    print()

    if missing:
        print(f"--- English dat/ exists but NO ko copy ({len(missing)}) ---")
        for m in missing:
            print(f"  dat/{m}")
        print()
    else:
        print("--- All expected help/data/lua copies exist ---\n")

    if lua_mismatch:
        print("--- Lua message call count mismatch ---")
        for m in lua_mismatch:
            print(f"  {m}")
        print()

    if data_note:
        print(f"--- data.base ---\n  {data_note}\n")

    print("--- English-like content IN dat/locale/ko/ (heuristic) ---")
    by_file: list[tuple[str, int, list]] = []
    total = 0
    for p in sorted(KO.rglob("*")):
        if not p.is_file() or p.suffix in (".mo", ".gz"):
            continue
        hits = scan_file(p)
        if hits:
            rel = p.relative_to(ROOT).as_posix()
            by_file.append((rel, len(hits), hits))
            total += len(hits)

    by_file.sort(key=lambda x: -x[1])
    for rel, n, hits in by_file[:12]:
        print(f"\n{rel} ({n} hits):")
        for ln, s in hits[:4]:
            print(f"  L{ln}: {s!r}")
        if n > 4:
            print(f"  ... +{n - 4} more")
    if not by_file:
        print("  (none found by heuristic)")
    print(f"\nTotal heuristic hits: {total}")
    print("\nNote: epitaph/oracles may keep Latin/English on purpose.")
    print("Note: data.base is often partially translated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
