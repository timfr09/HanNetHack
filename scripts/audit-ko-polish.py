#!/usr/bin/env python3
"""Audit ko_manual.po for translation polish candidates (report only)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PO = ROOT / "po" / "ko_manual.po"

DEBUG_SUBSTR = (
    "sanity_check",
    "weapon_check",
    "wall_angle",
    "check_version",
    "obj_nexto",
    "impossible",
    "Setworn",
)


def parse_po(text: str) -> list[dict]:
    entries: list[dict] = []
    cur: dict | None = None
    for line in text.splitlines():
        if line.startswith("msgid "):
            if cur:
                entries.append(cur)
            cur = {"refs": [], "msgid": "", "msgstr": "", "fuzzy": False}
            cur["msgid"] = unescape_po(line[6:].strip())
        elif line.startswith("msgstr ") and cur is not None:
            cur["msgstr"] = unescape_po(line[7:].strip())
        elif line.startswith("#:") and cur is not None:
            cur["refs"].append(line[3:].strip())
        elif line.startswith("#, fuzzy") and cur is not None:
            cur["fuzzy"] = True
    if cur:
        entries.append(cur)
    return entries


def unescape_po(s: str) -> str:
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1]
    return s


def hangul_ratio(s: str) -> float:
    if not s:
        return 0.0
    hangul = sum(1 for c in s if "\uac00" <= c <= "\ud7a3")
    return hangul / len(s)


def main() -> int:
    text = PO.read_text(encoding="utf-8")
    entries = parse_po(text)

    same: list[str] = []
    english_msgstr: list[tuple[str, str, str]] = []
    geot_gatda: list[tuple[str, str, str]] = []
    hayo_narrative: list[tuple[str, str, str]] = []
    hamnida_narrative: list[tuple[str, str, str]] = []

    for e in entries:
        mid, mst = e["msgid"], e["msgstr"]
        if not mid:
            continue
        ref = e["refs"][0] if e["refs"] else ""

        if mid == mst and len(mid) > 8:
            if not any(d in mid for d in DEBUG_SUBSTR):
                if mid[0].isalpha() and " " in mid and not mid.startswith("%"):
                    same.append(f"{ref}\t{mid[:100]}")

        if mst and hangul_ratio(mst) < 0.15 and sum(c.isalpha() for c in mst) > 12:
            if not any(d in mid for d in DEBUG_SUBSTR):
                english_msgstr.append((ref, mid[:80], mst[:100]))

        if "것 같" in mst and len(mst) < 120:
            geot_gatda.append((ref, mid[:70], mst[:90]))

        narr = mid.startswith(
            ("You ", "The ", "Your ", "A ", "An ", "It ", "Something ", "Unfortunately ")
        )
        if narr and mst:
            if re.search(r"해요", mst) and "말한다" not in mst:
                hayo_narrative.append((ref, mid[:70], mst[:90]))
            if re.search(r"(합니다|습니다)\.", mst) and "?" not in mst:
                hamnida_narrative.append((ref, mid[:70], mst[:90]))

    print(f"=== ko_manual.po polish audit ({PO.name}) ===\n")
    print(f"Entries with msgid: {sum(1 for e in entries if e['msgid'])}\n")

    sections = [
        ("Untranslated full sentences (msgid==msgstr)", same),
        ("English-heavy msgstr (low hangul)", english_msgstr),
        ('"것 같" in short msgstr (candidates for 듯하다)', geot_gatda),
        ("Narrative with 해요", hayo_narrative),
        ("Narrative ending 합니다/습니다", hamnida_narrative),
    ]

    for title, items in sections:
        print(f"## {title}: {len(items)}")
        show = items[:25]
        for row in show:
            if isinstance(row, str):
                print(f"  {row}")
            else:
                print(f"  {row[0]}")
                print(f"    id: {row[1]}")
                print(f"    tr: {row[2]}")
        if len(items) > 25:
            print(f"  ... and {len(items) - 25} more")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
