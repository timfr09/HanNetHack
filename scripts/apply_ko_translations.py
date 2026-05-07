#!/usr/bin/env python3
"""
Apply msgid->msgstr mappings to po/ko_manual.po (UTF-8).

기본: po/ko_translations_5_0_data.TR + po/ko_translations_remainder.json 를 합쳐 적용.
비어 있지 않은 칸은 건너뜀. remainder 정책 변경 후 일괄 반영은 --sync-all-in-catalog.

Usage:
  .venv-po/bin/python scripts/apply_ko_translations.py
  .venv-po/bin/python scripts/apply_ko_translations.py po/custom.json
  .venv-po/bin/python scripts/apply_ko_translations.py --refresh-prefix '〔점검〕'
  .venv-po/bin/python scripts/apply_ko_translations.py --sync-all-in-catalog
"""
import argparse
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
    ap = argparse.ArgumentParser(description="Apply TR + remainder JSON into ko_manual.po")
    ap.add_argument(
        "extra_json",
        nargs="?",
        default=None,
        help="Optional JSON file with extra msgid→msgstr mappings",
    )
    ap.add_argument(
        "--refresh-prefix",
        action="append",
        default=[],
        metavar="PREFIX",
        help="Replace existing msgstr when it starts with this prefix (repeatable). "
        "Example: --refresh-prefix '〔점검〕'",
    )
    ap.add_argument(
        "--sync-all-in-catalog",
        action="store_true",
        help="data(TR+remainder)에 존재하는 모든 msgid의 msgstr를 덮어쓴다. "
        "진단 문자열을 영어 유지로 되돌린 뒤 ko_manual.po에 일괄 반영할 때 사용.",
    )
    args = ap.parse_args()

    pofile = root / "po" / "ko_manual.po"
    data = load_tr_data(root)
    if args.extra_json:
        data.update(json.loads(Path(args.extra_json).read_text(encoding="utf-8")))

    refresh_prefixes = args.refresh_prefix

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
        if args.sync_all_in_catalog:
            entry.msgstr = data[mid]
            changed += 1
            continue
        msgstr = entry.msgstr or ""
        cur = msgstr.strip()
        allow_replace = False
        if cur:
            if refresh_prefixes and any(msgstr.startswith(p) for p in refresh_prefixes):
                allow_replace = True
            if not allow_replace:
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
