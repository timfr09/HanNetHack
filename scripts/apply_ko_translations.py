#!/usr/bin/env python3
"""
Apply msgid->msgstr mappings to po/ko_manual.po (UTF-8).

기본: po/ko_translations_5_0_data.TR + po/ko_translations_remainder.json 를 합쳐 적용.

Usage:
  .venv-po/bin/python scripts/apply_ko_translations.py
  .venv-po/bin/python scripts/apply_ko_translations.py po/custom.json   # 추가 덮어쓰기
"""
import importlib.util
import json
import sys
from pathlib import Path

try:
    import polib
except ImportError:
    print("Install polib: python3 -m venv .venv-po && .venv-po/bin/pip install polib", file=sys.stderr)
    sys.exit(1)


def load_tr_data(root: Path) -> dict:
    spec = importlib.util.spec_from_file_location(
        "ko_translations_5_0_data", root / "po" / "ko_translations_5_0_data.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    data = dict(mod.TR)
    rem = root / "po" / "ko_translations_remainder.json"
    if rem.is_file():
        data.update(json.loads(rem.read_text(encoding="utf-8")))
    return data


def main():
    root = Path(__file__).resolve().parent.parent
    pofile = root / "po" / "ko_manual.po"
    data = load_tr_data(root)
    if len(sys.argv) >= 2:
        data.update(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")))

    po = polib.pofile(str(pofile))
    changed = 0
    missing_keys = []
    for entry in po:
        if entry.obsolete:
            continue
        mid = entry.msgid
        if not mid:
            continue
        if mid not in data:
            continue
        # 비어 있거나 공백만 있는 항목만 채움(기존 번역 유지)
        if entry.msgstr and entry.msgstr.strip():
            continue
        entry.msgstr = data[mid]
        changed += 1

    po.save(str(pofile))
    print(f"Updated {changed} entries in {pofile}")
    if missing_keys:
        print(f"Still untranslated (not in JSON): {len(missing_keys)} (showing first 5 keys truncated)")
        for k in missing_keys[:5]:
            print("  ", repr(k))


if __name__ == "__main__":
    main()
