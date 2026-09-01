#!/usr/bin/env python3
"""Merge po/ko_menu_translations.json into ko_manual.po (msgctxt entries)."""
import json
import sys
from pathlib import Path

try:
    import polib
except ImportError:
    print("Install polib: python3 -m venv .venv-po && .venv-po/bin/pip install polib", file=sys.stderr)
    sys.exit(1)


def upsert(po, msgctxt, msgid, msgstr, comment):
    for entry in po:
        if entry.msgctxt == msgctxt and entry.msgid == msgid:
            if entry.msgstr != msgstr:
                entry.msgstr = msgstr
                if comment and comment not in entry.comment:
                    entry.comment = (entry.comment + "\n" + comment).strip()
            return False
    entry = polib.POEntry(msgctxt=msgctxt, msgid=msgid, msgstr=msgstr)
    entry.comment = comment
    po.append(entry)
    return True


def main():
    root = Path(__file__).resolve().parent.parent
    data = json.loads((root / "po" / "ko_menu_translations.json").read_text(encoding="utf-8"))
    po = polib.pofile(str(root / "po" / "ko_manual.po"))
    added = 0
    mapping = [
        ("extcmd", "extcmd", "# Extended command menu (cmd.c doextlist)"),
        ("extcmd_desc", "extcmd_desc", "# Extended command descriptions (cmd.c doextlist)"),
        ("symset", "symset", "# Symbol set names (symbols.c)"),
        ("symset_desc", "symset_desc", "# Symbol set descriptions (dat/symbols)"),
        ("status_field", "status_field", "# Status hilite field label (botl.c)"),
    ]
    for key, ctx, comment in mapping:
        block = data.get(key, {})
        for msgid, msgstr in block.items():
            if upsert(po, ctx, msgid, msgstr, comment):
                added += 1
    po.save(str(root / "po" / "ko_manual.po"))
    print(f"merge_ko_menu_translations: added {added} entries")


if __name__ == "__main__":
    main()
