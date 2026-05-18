#!/usr/bin/env python3
# SPDX-License-Identifier: NGPL
"""Apply HanNetHack structural i18n entries and fragment fixes to ko_manual.po.

Run once after source uses msgctxt / full-sentence patterns (see po header §5).
  python3 scripts/apply-ko-structural.py
"""
from __future__ import annotations

import re
from pathlib import Path

PO = Path(__file__).resolve().parents[1] / "po" / "ko_manual.po"

HEADER_NOTE = """\
# 5. HanNetHack 구조·플랫폼 (재수정 방지):
#    - 관사 조각(" the ", "The ", "a ")은 빈 문자열·공백·ZWSP만 쓴다. 문장은 소스에서 통째로.
#    - "X of Y"는 msgctxt+"%s of %s" 통합(item_of_effect, priest_of_deity 등). " of " 조각 이어붙이지 말 것.
#    - zap.c 파괴·pray.c 제단·dokick.c 낙기·lock.c 부러짐: 조각("One of ")+이름 조립 대신 C_() 완전 문장.
#    - MinGW/MSVC: 다인자 포맷은 msgstr에 %1$s… 위치 지정자 필수(scripts/fix-po-positional.py).
#    - " labeled " 조각: 소원/파서용. 화면 표시는 scroll_item "scroll labeled %s" 사용.
#
"""

MSGCTXT_BLOCK = """
# objnam.c - ring/scroll/potion/wand (item_of_effect)
#: ../src/objnam.c:291
msgctxt "item_of_effect"
msgid "%s of %s"
msgstr "%2$s의 %1$s"

# objnam.c - figurine (figurine_of_monster)
#: ../src/objnam.c:718
msgctxt "figurine_of_monster"
msgid "%s of %s"
msgstr "%2$s %1$s"

# priest.c - deity title (priest_of_deity)
# %1$s=직함(대사제 등), %2$s=신 이름 — "몰록 신의 대사제"
#: ../src/priest.c:373
msgctxt "priest_of_deity"
msgid "%s of %s"
msgstr "%2$s 신의 %1$s"

# priest.c - hallucinated high priest title
#: ../src/priest.c:325
msgid "grand poohbah"
msgstr "위대한 푸바"

# objnam.c - magic scroll with bogus label (scroll_item)
#: ../src/objnam.c:873
msgctxt "scroll_item"
msgid "scroll labeled %s"
msgstr "라벨이 %s인 두루마리"

# --- zap.c destroy_items (zap_destroy*): %1$s=물건명(yname), %2$s=동사구 ---
#: ../src/zap.c:5909
msgctxt "zap_destroy"
msgid "%1$s %2$s!"
msgstr "%1$s %2$s!"

#: ../src/zap.c:5911
msgctxt "zap_destroy_one_of_n"
msgid "%1$s %2$s!"
msgstr "%1$s 중 하나가 %2$s!"

#: ../src/zap.c:5913
msgctxt "zap_destroy_some_of_n"
msgid "%1$s %2$s!"
msgstr "%1$s 일부가 %2$s!"

#: ../src/zap.c:5915
msgctxt "zap_destroy_both"
msgid "%1$s %2$s!"
msgstr "%1$s 둘 다 %2$s!"

#: ../src/zap.c:5917
msgctxt "zap_destroy_all"
msgid "%1$s %2$s!"
msgstr "%1$s 모두 %2$s!"

# lock.c - force lock breaks pick (replaces "%sour %s broke!" / One of y)
#: ../src/lock.c:239
#, c-format
msgid "One of your %s broke!"
msgstr "당신의 %1$s 중 하나가 부러졌다!"

#: ../src/lock.c:241
#, c-format
msgid "Your %s broke!"
msgstr "당신의 %1$s{이/가} 부러졌다!"

# pray.c water_prayer (replaces potion+s+glow+s glue)
#: ../src/pray.c:1413
#, c-format
msgid "The potion on the altar glows %s for a moment."
msgstr "제단 위 물약이 잠시 %1$s 빛을 낸다."

#: ../src/pray.c:1415
#, c-format
msgid "One of the potions on the altar glows %s for a moment."
msgstr "제단 위 물약 중 하나가 잠시 %1$s 빛을 낸다."

#: ../src/pray.c:1417
#, c-format
msgid "Some of the potions on the altar glow %s for a moment."
msgstr "제단 위 물약 일부가 잠시 %1$s 빛을 낸다."

#: ../src/pray.c:1419
#, c-format
msgid "The potions on the altar glow %s for a moment."
msgstr "제단 위 물약들이 잠시 %1$s 빛을 낸다."

# artifact.c - demon vanish (subject: existing msgid demon/demons)
#: ../src/artifact.c:2013
#, c-format
msgid "The %s %s in a cloud of brimstone!"
msgstr "%1$s{이/가} 유황 구름 속으로 %2$s!"

#: ../src/artifact.c:2015
#, c-format
msgid "Most of the %s %s in a cloud of brimstone!"
msgstr "대부분의 %1$s{이/가} 유황 구름 속으로 %2$s!"

#: ../src/artifact.c:2017
#, c-format
msgid "Some of the %s %s in a cloud of brimstone!"
msgstr "일부 %1$s{이/가} 유황 구름 속으로 %2$s!"

# dokick.c - gate kick fall (replaces adjacent fragment glue)
#: ../src/dokick.c:1607
#, c-format
msgid "From the impact, the other %s."
msgstr "충격으로 다른 %1$s."

#: ../src/dokick.c:1609
#, c-format
msgid "From the impact, another %s."
msgstr "충격으로 또 다른 %1$s."

#: ../src/dokick.c:1611
#, c-format
msgid "From the impact, other %s."
msgstr "충격으로 나머지 %1$s."

#: ../src/dokick.c:1614
#, c-format
msgid "The adjacent %s %s."
msgstr "인접한 %1$s{이/가} %2$s."

#: ../src/dokick.c:1616
#, c-format
msgid "All the adjacent %s %s."
msgstr "인접한 %1$s 모두 %2$s."

#: ../src/dokick.c:1618
#, c-format
msgid "One of the adjacent objects falls %s."
msgstr "인접한 물건 중 하나가 %1$s."

#: ../src/dokick.c:1620
#, c-format
msgid "Some of the adjacent %s %s."
msgstr "인접한 %1$s 일부가 %2$s."

# end.c - named ghost (ghost_of)
#: ../src/end.c:266
msgctxt "ghost_of"
msgid "%s of %s"
msgstr "%2$s의 %1$s"

# eat.c - tin contents (tin_of_meat)
#: ../src/eat.c:1460
msgctxt "tin_of_meat"
msgid "%s of %s"
msgstr "%2$s %1$s"

# eat.c - tin with quality prefix (tin_with_quality)
#: ../src/eat.c:1453 ../src/eat.c:1456
msgctxt "tin_with_quality"
msgid "%s %s of %s"
msgstr "%1$s %3$s %2$s"

#: ../src/eat.c:1456
msgctxt "tin_with_quality"
msgid "%s of %s %s"
msgstr "%1$s %2$s %3$s"

"""

FRAGMENT_FIXES = {
    " the ": " ",
    "The ": "",
    "This ": "이 ",
    "Some of ": "일부 ",
    "in ": " ",
    "a ": " ",
    "the ": "",
    " of ": " ",  # legacy fragment; prefer msgctxt above
    "Some of the": "일부의",
    "One of ": " ",  # legacy; zap uses zap_destroy_*
    "One of the": "중 하나의",
    "One of y": "",  # obsolete (lock.c uses full sentence)
    " labeled ": " (라벨: ",  # parser/wish only; display uses scroll_item
}

def main() -> None:
    text = PO.read_text(encoding="utf-8")

    if "# 5. HanNetHack 구조" not in text:
        text = text.replace(
            "#    - experience → 경험치\n#\nmsgid \"\"",
            "#    - experience → 경험치\n#\n" + HEADER_NOTE + 'msgid ""',
            1,
        )

    if 'msgctxt "item_of_effect"' not in text:
        anchor = '#: ../src/eat.c:1450 ../src/obj_descr_i18n.c:524 ../src/priest.c:364\nmsgid " of "\nmsgstr " of "\n'
        if anchor not in text:
            anchor = 'msgid " of "\nmsgstr " of "\n'
        text = text.replace(
            anchor,
            'msgid " of "\nmsgstr " "\n' + MSGCTXT_BLOCK,
            1,
        )

    for mid, mst in FRAGMENT_FIXES.items():
        pat = f'msgid "{mid}"\nmsgstr "'
        if mid not in (' of ',):  # of handled above
            esc = mid.replace("\\", "\\\\").replace('"', '\\"')
            text, n = re.subn(
                rf'msgid "{re.escape(mid)}"\nmsgstr "[^"]*"',
                f'msgid "{esc}"\nmsgstr "{mst}"',
                text,
                count=1,
            )

    # demons plural for artifact.c
    text, _ = re.subn(
        r'(#: ../src/insight\.c:1645.*\nmsgid "demons"\nmsgstr ")[^"]*(")',
        r'\1악마들\2',
        text,
        count=1,
    )

    PO.write_text(text, encoding="utf-8")
    print(f"Updated {PO}")

if __name__ == "__main__":
    main()
