#!/usr/bin/env python3
"""
Sync new msgid entries from ko.po into ko_manual.po.

This script appends entries that exist in ko.po but not in ko_manual.po,
preserving their original PO block content as stubs for manual translation.
"""

from __future__ import annotations

import argparse
import datetime as _dt
from pathlib import Path
from typing import Dict, List, Optional, Tuple


EntryKey = Tuple[Optional[str], str, Optional[str]]


def _decode_po_string(lines: List[str], start_idx: int) -> Tuple[str, int]:
    """Decode msgid/msgctxt/msgid_plural value with continuation lines."""
    line = lines[start_idx].strip()
    first_quote = line.find('"')
    if first_quote < 0:
        return "", start_idx
    value = _unescape_po(line[first_quote:])
    i = start_idx + 1
    while i < len(lines):
        s = lines[i].strip()
        if not s.startswith('"'):
            break
        value += _unescape_po(s)
        i += 1
    return value, i - 1


def _unescape_po(quoted: str) -> str:
    # quoted must include surrounding double quotes
    if len(quoted) >= 2 and quoted[0] == '"' and quoted[-1] == '"':
        inner = quoted[1:-1]
    else:
        inner = quoted
    return bytes(inner, "utf-8").decode("unicode_escape")


def _split_blocks(text: str) -> List[List[str]]:
    lines = text.splitlines(keepends=True)
    blocks: List[List[str]] = []
    cur: List[str] = []
    for ln in lines:
        if ln.strip() == "":
            if cur:
                blocks.append(cur)
                cur = []
        else:
            cur.append(ln)
    if cur:
        blocks.append(cur)
    return blocks


def _entry_key(block: List[str]) -> Optional[EntryKey]:
    msgctxt: Optional[str] = None
    msgid: Optional[str] = None
    msgid_plural: Optional[str] = None

    i = 0
    while i < len(block):
        s = block[i].lstrip()
        if s.startswith("msgctxt "):
            msgctxt, i = _decode_po_string(block, i)
        elif s.startswith("msgid_plural "):
            msgid_plural, i = _decode_po_string(block, i)
        elif s.startswith("msgid "):
            msgid, i = _decode_po_string(block, i)
        i += 1

    if msgid is None or msgid == "":
        return None
    return (msgctxt, msgid, msgid_plural)


def _collect_entries(path: Path) -> Dict[EntryKey, List[str]]:
    text = path.read_text(encoding="utf-8")
    out: Dict[EntryKey, List[str]] = {}
    for block in _split_blocks(text):
        key = _entry_key(block)
        if key is not None:
            out[key] = block
    return out


def sync_new_entries(manual_path: Path, auto_path: Path) -> int:
    manual_entries = _collect_entries(manual_path)
    auto_entries = _collect_entries(auto_path)

    missing_keys = [k for k in auto_entries.keys() if k not in manual_entries]
    if not missing_keys:
        return 0

    ts = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with manual_path.open("a", encoding="utf-8", newline="") as f:
        f.write("\n")
        f.write("# ============================================================\n")
        f.write(f"# Auto-imported new msgids from ko.po ({ts})\n")
        f.write("# Added as stubs for manual translation in ko_manual.po\n")
        f.write("# ============================================================\n\n")
        for key in missing_keys:
            for ln in auto_entries[key]:
                f.write(ln)
            f.write("\n")
    return len(missing_keys)


def main() -> int:
    p = argparse.ArgumentParser(description="Sync new msgids into ko_manual.po")
    p.add_argument("--manual", default="ko_manual.po")
    p.add_argument("--auto", default="ko.po")
    args = p.parse_args()

    manual = Path(args.manual)
    auto = Path(args.auto)
    if not manual.exists():
        raise SystemExit(f"Manual PO not found: {manual}")
    if not auto.exists():
        raise SystemExit(f"Auto PO not found: {auto}")

    added = sync_new_entries(manual, auto)
    print(f"synced_new_msgids={added}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

