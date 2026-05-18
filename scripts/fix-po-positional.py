#!/usr/bin/env python3
# SPDX-License-Identifier: NGPL
"""Add %1$s positional forms to ko_manual.po msgstr (MinGW _vsprintf_p).

Run only after `apply-ko-structural.py`; then `cd po && make translation-ci`.
If msgfmt reports errors, revert this script's output (git checkout po/ko_manual.po)
and add positional only to new msgctxt entries by hand.

Skips: multiline msgstr, empty msgstr, width/precision (%.60s), any existing %N$,
       msgid/msgstr conversion count mismatch, reordered translations (%2$s before %1$s).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PLAIN_CONV = re.compile(r"%([-.0-9]*)([sdulc]|ld|lld|lu|llu)(?![a-zA-Z])")

def plain_conversions(s: str) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(s):
        if s[i : i + 2] == "%%":
            i += 2
            continue
        if s[i] == "%" and (i + 1 >= len(s) or not s[i + 1].isdigit()):
            m = PLAIN_CONV.match(s, i)
            if m and not m.group(1):
                out.append(m.group(2))
                i += m.end() - i
                continue
        i += 1
    return out

def has_width_prec(s: str) -> bool:
    return bool(re.search(r"%[-+ #0]*\d*\.", s))

def add_positional(msgstr: str) -> str:
    n = 1
    out: list[str] = []
    i = 0
    while i < len(msgstr):
        if msgstr[i : i + 2] == "%%":
            out.append("%%")
            i += 2
            continue
        if msgstr[i] == "%" and (i + 1 >= len(msgstr) or not msgstr[i + 1].isdigit()):
            m = PLAIN_CONV.match(msgstr, i)
            if m and not m.group(1):
                out.append(f"%{n}${m.group(2)}")
                n += 1
                i += m.end()
                continue
        out.append(msgstr[i])
        i += 1
    return "".join(out)

def process_po(text: str) -> tuple[str, int]:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    changed = 0
    while i < len(lines):
        if not lines[i].startswith("msgid "):
            out.append(lines[i])
            i += 1
            continue
        block = [lines[i]]
        i += 1
        while i < len(lines) and lines[i].startswith('"'):
            block.append(lines[i])
            i += 1
        parts = re.findall(r'"((?:[^"\\]|\\.)*)"', "".join(block))
        msgid = parts[0] if parts else ""

        msgstr_block: list[str] = []
        if i < len(lines) and lines[i].startswith("msgstr "):
            msgstr_block.append(lines[i])
            i += 1
            while i < len(lines) and lines[i].startswith('"'):
                msgstr_block.append(lines[i])
                i += 1

        out.extend(block)
        if not msgstr_block:
            continue
        if len(msgstr_block) > 1 or msgstr_block[0].rstrip().endswith('""'):
            out.extend(msgstr_block)
            continue
        parts_m = re.findall(r'"((?:[^"\\]|\\.)*)"', msgstr_block[0])
        msgstr = parts_m[0] if parts_m else ""
        if not msgstr or "$" in msgstr:
            out.extend(msgstr_block)
            continue
        if has_width_prec(msgid) or has_width_prec(msgstr):
            out.extend(msgstr_block)
            continue
        mid_c = plain_conversions(msgid)
        mst_c = plain_conversions(msgstr)
        if len(mst_c) < 2 or mid_c != mst_c:
            out.extend(msgstr_block)
            continue
        new_mst = add_positional(msgstr)
        if new_mst != msgstr:
            changed += 1
            esc = new_mst.replace("\\", "\\\\").replace('"', '\\"')
            out.append(f'msgstr "{esc}"\n')
            continue
        out.extend(msgstr_block)
    return "".join(out), changed

def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "po/ko_manual.po")
    text = path.read_text(encoding="utf-8")
    new_text, n = process_po(text)
    if n:
        path.write_text(new_text, encoding="utf-8")
        print(f"Updated {n} msgstr entries in {path}")
    else:
        print("No entries changed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
