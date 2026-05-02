#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
578개 미번역 문자열용 한국어 생성.
- 플레이어에게 보일 수 있는 문장은 자연스러운 게임체('-다')로 번역.
- 내부 impossible()류는 '함수명: 한국어 설명' 형태로 로그 가독성 유지.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from ko_translations_5_0_data import TR  # noqa: E402

# --- 플레이어·UI에 가까운 문구 (전체 문장 번역) ---
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

# --- 자주 나오는 영문 꼬리 → 한국어 ---
TAIL_SUB = [
    (re.compile(r"^obj not free$", re.I), "객체가 자유 상태가 아니다"),
    (re.compile(r"^can't find (.+)$", re.I), r"찾을 수 없다: \1"),
    (re.compile(r"^unexpected (.+)$", re.I), r"예기치 않은 \1"),
    (re.compile(r"^unknown (.+)$", re.I), r"알 수 없는 \1"),
    (re.compile(r"^bad (.+)$", re.I), r"잘못된 \1"),
    (re.compile(r"^invalid (.+)$", re.I), r"유효하지 않은 \1"),
    (re.compile(r"^no (.+)$", re.I), r"\1이(가) 없다"),
]


def translate_tail(tail: str) -> str:
    s = tail.strip()
    for rx, rep in TAIL_SUB:
        m = rx.match(s)
        if m:
            return rx.sub(rep, s, count=1)
    # 일반 규칙
    s = re.sub(r"\bobj\b", "객체", s, flags=re.I)
    s = re.sub(r"\bmonster\b", "몬스터", s, flags=re.I)
    s = re.sub(r"\bnot free\b", "자유 상태가 아니다", s, flags=re.I)
    s = re.sub(r"\bbad\b", "잘못된", s, flags=re.I)
    return s


def translate_one(msgid: str) -> str:
    if msgid in FULL:
        return FULL[msgid]

    # 함수명: 설명
    if ": " in msgid and not msgid.startswith("%"):
        head, tail = msgid.split(": ", 1)
        # 코드 식별자는 유지
        return f"{head}: {translate_tail(tail)}"

    # 짧은 구호형
    if msgid.endswith("?"):
        core = msgid[:-1].strip()
        if core.lower().startswith("already have"):
            return core.replace("already have", "이미 가지고 있다") + "?"
        if "can't" in core.lower():
            return translate_tail(core) + "?"

    # 패턴 치환
    out = msgid
    out = re.sub(r"\bbad\b", "잘못된", out, flags=re.I)
    out = re.sub(r"\bcan't\b", "할 수 없다", out, flags=re.I)
    out = re.sub(r"\bunknown\b", "알 수 없는", out, flags=re.I)
    out = re.sub(r"\berror\b", "오류", out, flags=re.I)
    if out == msgid and len(msgid) < 90:
        return f"〔점검〕 {msgid}"
    return out


def main():
    keys = json.load(open(ROOT / "_keys.json", encoding="utf-8"))
    missing = [k for k in keys if k not in TR]
    rem = {k: translate_one(k) for k in missing}
    out = ROOT / "ko_translations_remainder.json"
    json.dump(rem, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"Wrote {len(rem)} entries to {out}")


if __name__ == "__main__":
    main()
