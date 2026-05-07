#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TR(ko_translations_5_0_data)에 없는 msgid에 대해 ko_translations_remainder.json 을 만든다.

기본 정책(TRANSLATION_GUIDE_KO.md):
- **플레이어가 통상 보는** UI·질문·짧은 게임 텍스트만 한국어로 둔다.
- `impossible()`·내부 진단·시스템 오류에 가까운 문자열은 **번역하지 않고 영어 msgid를 그대로** 넣는다
  (apply 시 msgstr==msgid → 런타임에서도 영어와 동일).

한국어를 넣는 경우: 아래 FULL / _SHORT_LITERAL_KO / 퀘스트용 질문, 그리고 remainder_quality_patch.json 수동 항목뿐.

다음: scripts/apply_ko_translations.py (빈 칸 또는 --sync-all-in-catalog)

의존성: polib

Usage:
  python3 build_remainder_translations.py
  python3 build_remainder_translations.py --refresh-all
  python3 build_remainder_translations.py --keys-json _keys.json
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path

try:
    import polib
except ImportError:
    print(
        "Install polib: python3 -m venv .venv-po && .venv-po/bin/pip install polib",
        file=sys.stderr,
    )
    sys.exit(1)


def load_tr(root: Path) -> dict:
    spec = importlib.util.spec_from_file_location(
        "ko_translations_5_0_data", root / "ko_translations_5_0_data.py"
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return dict(mod.TR)


def load_optional_patch(root: Path) -> dict[str, str]:
    p = root / "remainder_quality_patch.json"
    if not p.is_file():
        return {}
    raw = json.loads(p.read_text(encoding="utf-8"))
    return {str(k): str(v) for k, v in raw.items()}


def patch_translate(msgid: str, patch: dict[str, str]) -> str | None:
    if not patch:
        return None
    for k in (msgid, msgid.rstrip(), msgid.strip(), msgid.lstrip()):
        if k in patch:
            return patch[k]
    return None


# 퀘스트·소지품 점검(플레이어에게 보일 수 있음)
_ITEM_TAIL_KO = {
    "amulet": "부적",
    "the book": "그 책",
    "candelabrum": "일곱 양초 샹들리에",
    "quest artifact": "퀘스트 성물",
    "silver bell": "은종",
}

# 짧은 게임 내 표기(재료·함정 이름 등) — 화면에 나올 수 있음
_SHORT_LITERAL_KO = {
    "banana peel": "바나나 껍질",
    "bone oil": "뼈 기름",
    "custard": "커스터드",
    "lard": "라드",
    "creosote": "크리오소트",
    "fly trap": "파리지옥",
    "garden rake": "정원 갈퀴",
    "vinegar": "식초",
    "suntrap": "햇빛 함정",
    "thirst trap": "갈증 함정",
    "slippery slope": "미끄러운 비탈",
    "pit of snakes": "뱀이 우글거리는 구덩이",
    "pollywog trap": "올챙이 함정",
    "whoopie cushion": "방귀 방석",
    "legal trap": "합법 함정",
    "throne effect": "왕좌 효과",
    "ring replacement": "반지 교체",
    "box and stick trap": "상자·막대 함정",
    "bot before init.": "init 전 bot.",
    "freakishly ": "기이하게 ",
}

# UI·플레이어 대면에 가깝다고 판단되는 전체 문장만
FULL = {
    "Two-weapon insanity: %s.": "쌍수 무기 처리가 이상하다: %s.",
    "Unknown invoke power %d.": "알 수 없는 발동 능력 %d.",
    "Unknown item action %d": "알 수 없는 아이템 동작 %d",
    "Unknown room type '%s'": "알 수 없는 방 유형 '%s'",
    "Unknown spell %d attempted.": "알 수 없는 주문 %d를 시도했다.",
    "Unknown spell skill, %d;": "알 수 없는 주문 숙련도, %d;",
    "Unknown spellbook level %d, book %d;": "알 수 없는 마법서 단계 %d, 책 %d;",
    "Unknown tip in handle_tip(%i)": "handle_tip(%i)에서 알 수 없는 팁",
    "Unknown type of gloves (%d)": "알 수 없는 장갑 유형 (%d)",
    "Unrecognized gradient type! Defaulting to radial...": "인식할 수 없는 그라데이션 유형이다. 방사형으로 되돌린다…",
    "Unrecognized level init style.": "인식할 수 없는 층 초기화 방식이다.",
    "Unsupported damage type (%d) for mon_spell_hits_spot.": "mon_spell_hits_spot에서 지원하지 않는 피해 유형 (%d).",
    "Use #optionsfull to set any option instead.": "다른 옵션은 #optionsfull 로도 설정할 수 있습니다.",
    "Warning - Unclosed fieldlevel file being reinitialized": "경고 — 닫히지 않은 fieldlevel 파일을 다시 초기화한다",
    "Warning - Unclosed structlevel file being reinitialized": "경고 — 닫히지 않은 structlevel 파일을 다시 초기화한다",
    "Webbing over trap type %d?": "함정 유형 %d 위에 거미줄?",
    "Weird weapon special attack.": "이상한 무기 특수 공격이다.",
    "What a funny potion! (%u)": "우스운 물약이다! (%u)",
    "What a weird instrument (%d)!": "기묘한 도구다! (%d)",
    "What an interesting effect (%d)": "흥미로운 효과다 (%d)",
    "What weird effect is this? (%u)": "무슨 기묘한 효과인가? (%u)",
    "What weird role is this? (%s)": "무슨 기묘한 직업인가? (%s)",
    "Where are your ball and chain?": "철구와 쇠사슬은 어디 있는가?",
    "Where is shopdoor?": "상점 문은 어디 있는가?",
    "Worn-slot insanity: %s.": "착용 슬롯 처리가 이상하다: %s.",
    "Xp:%d/%ld": "경험치:%d/%ld",
    "You can't write such a weird scroll!": "그런 기묘한 두루마리에는 쓸 수 없다!",
    "You're engraving with an illegal object!": "허용되지 않은 물건으로 각인하고 있다!",
    "Zero quantity on bill??": "청구서 수량이 0??",
}


def translate_inventory_question(msgid: str) -> str | None:
    if not msgid.endswith("?"):
        return None
    core = msgid[:-1].strip()

    m = re.match(r"already have (.+)$", core, re.I)
    if m:
        phrase = m.group(1).strip()
        ko = _ITEM_TAIL_KO.get(phrase.lower(), phrase)
        return f"{ko}을(를) 이미 가지고 있는가?"

    m = re.match(r"don'?t have (.+)$", core, re.I)
    if m:
        phrase = m.group(1).strip()
        ko = _ITEM_TAIL_KO.get(phrase.lower(), phrase)
        return f"{ko}이(가) 없는가?"

    return None


def translate_one(msgid: str, patch: dict[str, str]) -> str:
    """한국어가 필요 없으면 msgid(영어)를 그대로 반환."""
    hit = patch_translate(msgid, patch)
    if hit is not None:
        return hit
    m = msgid.rstrip()
    if m in FULL:
        return FULL[m]
    if m in _SHORT_LITERAL_KO:
        return _SHORT_LITERAL_KO[m]

    inv = translate_inventory_question(m)
    if inv is not None:
        return inv

    return msgid


def msgids_empty_in_manual(po_path: Path) -> list[str]:
    po = polib.pofile(str(po_path))
    out: list[str] = []
    for entry in po:
        if entry.obsolete:
            continue
        mid = entry.msgid
        if not mid:
            continue
        if entry.msgstr and entry.msgstr.strip():
            continue
        out.append(mid)
    return out


def main() -> int:
    root = Path(__file__).resolve().parent
    p = argparse.ArgumentParser(
        description="Generate ko_translations_remainder.json (Korean only where justified; else English msgid)."
    )
    p.add_argument(
        "--manual",
        type=Path,
        default=root / "ko_manual.po",
        help="Source PO with empty msgstr entries to fill (default: ko_manual.po)",
    )
    p.add_argument(
        "--out",
        type=Path,
        default=root / "ko_translations_remainder.json",
        help="Output JSON mapping msgid -> msgstr suggestion",
    )
    p.add_argument(
        "--keys-json",
        type=Path,
        default=None,
        help="Optional JSON array of msgids (legacy). If set, manual empty-scan is skipped.",
    )
    p.add_argument(
        "--refresh-all",
        action="store_true",
        help="Rebuild every msgid in output JSON (plus manual empties) not in TR.",
    )
    args = p.parse_args()

    tr = load_tr(root)
    patch = load_optional_patch(root)

    prev: dict[str, str] = {}
    if args.out.is_file():
        try:
            prev = json.loads(args.out.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            prev = {}

    if args.keys_json is not None:
        if not args.keys_json.is_file():
            print(f"Keys file not found: {args.keys_json}", file=sys.stderr)
            return 1
        keys = json.loads(args.keys_json.read_text(encoding="utf-8"))
        missing = [k for k in keys if k not in tr]
    else:
        if not args.manual.is_file():
            print(f"Manual PO not found: {args.manual}", file=sys.stderr)
            return 1
        keys = msgids_empty_in_manual(args.manual)
        missing = [k for k in keys if k not in tr]

    if args.refresh_all:
        todo = set(prev.keys()) | set(missing)
        todo = {k for k in todo if k not in tr}
        rem = {k: translate_one(k, patch) for k in sorted(todo)}
    else:
        rem = dict(prev)
        for k in missing:
            rem[k] = translate_one(k, patch)
    args.out.write_text(
        json.dumps(rem, ensure_ascii=False, indent=0) + "\n", encoding="utf-8"
    )
    print(f"Wrote {len(rem)} entries to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
