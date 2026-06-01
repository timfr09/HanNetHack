#!/usr/bin/env python3
"""Polish ko_manual.po: 것 같다→듯하다, wish fragment, deity line, etc."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PO = ROOT / "po" / "ko_manual.po"

# Keep 존댓말 engraving prompt as-is (already natural)
SKIP_MSGID = frozenset(
    {
        "That is a bit difficult to engrave with, don't you think?",
    }
)

# Exact msgid overrides (not covered by rules)
EXACT: dict[str, str] = {
    'pieces"), although that aspect of your wish might not be granted.': (
        '조각"처럼 수량을 지정할 수 있지만, 그 부분은 허락되지 않을 수 있다.'
    ),
    "Thou hast angered me.": "네가 나를 노하게 했다.",
    "steed left behind?": "탈것이 뒤에 남았다?",
}


def polish_msgstr(msgid: str, msgstr: str) -> str:
    if msgid in EXACT:
        return EXACT[msgid]
    if msgid in SKIP_MSGID:
        return msgstr
    if "것 같" not in msgstr:
        return msgstr

    s = msgstr
    for old, new in (
        ("추워하는 것 같다", "오싹한 듯하다"),
        ("고정된 것 같다", "굳어진 듯하다"),
        ("비어있는 것 같다", "비어 있는 듯하다"),
        ("하이호, 호험, 오늘은 일을 안 할 것 같다", "하이호, 호험, 오늘은 일을 쉬어야겠다"),
        ("찡그리는 것 같다", "움찔한다"),
        ("소화불량인 것 같다", "소화가 안 되는 듯하다"),
        ("잡고 있는 것 같다", "붙잡고 있는 듯하다"),
        ("유연해진 것 같다", "몸이 유연해진 듯하다"),
        ("굶주린 것 같다", "굶주려 보인다"),
        ("토할 것 같다!", "토할 듯하다!"),
        ("토할 것 같다.", "메스꺼운 듯하다."),
        ("무서워서 죽을 것 같음", "무서워 죽을 지경"),
        ("겁에 질린 것 같다", "겁에 질린 듯하다"),
        ("알아채지 못한 것 같다", "알아채지 못한 듯하다"),
        ("느리게 움직이는 것 같다", "느리게 움직이는 듯하다"),
        ("움츠리는 것 같다", "움츠린다"),
    ):
        s = s.replace(old, new)

    for old, new in (
        ("것 같지 않으세요", "듯하지 않으세요"),
        ("것 같지 않다", "듯하지 않다"),
        ("것 같다고", "듯하다고"),
        ("것 같은", "듯한"),
        ("것 같음", "듯함"),
        ("것 같다.", "듯하다."),
        ("것 같다!", "듯하다!"),
        ("것 같다...", "듯하다..."),
        ("것 같다)", "듯하다)"),
        ("것 같다%.0s", "듯하다%.0s"),
        ("것 같다", "듯하다"),
    ):
        s = s.replace(old, new)
    return s


def apply(text: str) -> tuple[str, int]:
    changed = 0
    parts = re.split(r"(\n\n+)", text)
    out: list[str] = []
    i = 0
    while i < len(parts):
        block = parts[i]
        sep = parts[i + 1] if i + 1 < len(parts) and parts[i + 1].startswith("\n\n") else ""
        i += 2 if sep else 1

        m_id = re.search(r'^msgid "(.*)"$', block, re.M)
        m_st = re.search(r'^msgstr "(.*)"$', block, re.M)
        if m_id and m_st:
            mid, mst = m_id.group(1), m_st.group(1)
            new_st = polish_msgstr(mid, mst)
            if new_st != mst:
                esc = (
                    new_st.replace("\\", "\\\\")
                    .replace('"', '\\"')
                    .replace("\n", "\\n")
                )
                if re.search(r'^msgstr ".*"$', block, re.M):
                    block = re.sub(
                        r'^msgstr ".*"$',
                        f'msgstr "{esc}"',
                        block,
                        count=1,
                        flags=re.M,
                    )
                else:
                    continue
                changed += 1
        out.append(block + sep)
    return "".join(out), changed


def main() -> int:
    dry = "--dry-run" in sys.argv
    text = PO.read_text(encoding="utf-8")
    new_text, n = apply(text)
    print(f"Polish updates: {n} entries")
    if dry:
        return 0
    if n:
        PO.write_text(new_text, encoding="utf-8")
        print(f"Wrote {PO}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
