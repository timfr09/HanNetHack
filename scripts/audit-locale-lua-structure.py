#!/usr/bin/env python3
"""Deep EN vs KO Lua sync — catches what line-count checks miss.

Locale KO Lua is a full fork: Korean copy often omits gettext `_()`,
reorders `string.format` args, and puts keys after Korean text. Those
are expected. This audit flags:

  - real logic drift (new des.*/nh.* calls, missing functions)
  - player-message count mismatch (after normalizing `_()`)
  - KO UI strings still in English

Usage: python3 scripts/audit-locale-lua-structure.py
"""
from __future__ import annotations

import difflib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DAT = ROOT / "dat"
KO = DAT / "locale" / "ko"


def strip_to_logic(src: str) -> list[str]:
    """Code skeleton: drop comments/strings; normalize _(\"...\") → \"STR\"."""
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        if src.startswith("--", i):
            j = src.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        if src.startswith("[[", i):
            j = src.find("]]", i + 2)
            out.append("[[STR]]")
            i = n if j < 0 else j + 2
            continue
        # normalize _("...") / _( [[...]] ) — drop wrapper and its closing ')'
        if src.startswith("_(", i):
            i += 2
            while i < n and src[i].isspace():
                i += 1
            if src.startswith("[[", i):
                j = src.find("]]", i + 2)
                out.append("[[STR]]")
                i = n if j < 0 else j + 2
            elif i < n and src[i] in "\"'":
                q = src[i]
                i += 1
                while i < n:
                    if src[i] == "\\" and i + 1 < n:
                        i += 2
                        continue
                    if src[i] == q:
                        i += 1
                        break
                    i += 1
                out.append('"STR"')
            while i < n and src[i].isspace():
                i += 1
            if i < n and src[i] == ")":
                i += 1  # eat _( ... )
            continue
        ch = src[i]
        if ch in "\"'":
            q = ch
            i += 1
            while i < n:
                if src[i] == "\\" and i + 1 < n:
                    i += 2
                    continue
                if src[i] == q:
                    i += 1
                    break
                i += 1
            out.append('"STR"')
            continue
        out.append(ch)
        i += 1
    lines = []
    for line in "".join(out).splitlines():
        s = re.sub(r"\s+", " ", line).strip()
        # drop lone closing paren left by _(
        s = s.replace("( \"STR\" )", '("STR")')
        s = re.sub(r'\( "STR" \)', '("STR")', s)
        if s:
            lines.append(s)
    return lines


def ignore_logic_line(line: str) -> bool:
    """True if difference is an expected KO adaptation."""
    # format arg order only (direction vs count) — both are string.format
    if "string.format" in line:
        return True
    # engraving text concat order: keys .. text vs text .. keys
    if "engraving" in line and ("movekeys" in line or "diagmovekeys" in line or "tut_key" in line or "tut_ctrl" in line):
        return True
    return False


def logic_diff(ko_lines: list[str], en_lines: list[str]) -> list[str]:
    raw = list(
        difflib.unified_diff(
            ko_lines, en_lines, fromfile="KO", tofile="EN", lineterm="", n=0
        )
    )
    # filter hunks that are only expected adaptations
    meaningful: list[str] = []
    pending: list[str] = []
    for line in raw:
        if line.startswith("@@"):
            if pending and not all(
                ignore_logic_line(l[1:]) for l in pending if l.startswith(("+", "-")) and not l.startswith(("+++", "---"))
            ):
                meaningful.extend(pending)
            pending = [line]
            continue
        if line.startswith(("+", "-")) and not line.startswith(("+++", "---")):
            pending.append(line)
        elif pending:
            pending.append(line)
    if pending and not all(
        ignore_logic_line(l[1:]) for l in pending if l.startswith(("+", "-")) and not l.startswith(("+++", "---"))
    ):
        meaningful.extend(pending)
    return meaningful


def parse_string_at(text: str, start: int) -> tuple[str, int] | None:
    if text.startswith("[[", start):
        end = text.find("]]", start + 2)
        if end < 0:
            return None
        return text[start + 2 : end], end + 2
    if start < len(text) and text[start] == '"':
        i = start + 1
        buf: list[str] = []
        while i < len(text):
            if text[i] == "\\" and i + 1 < len(text):
                buf.append(text[i : i + 2])
                i += 2
                continue
            if text[i] == '"':
                return "".join(buf), i + 1
            buf.append(text[i])
            i += 1
    return None


def find_call_strings(text: str, func: str) -> list[str]:
    msgs: list[str] = []
    i = 0
    while True:
        p = text.find(func, i)
        if p < 0:
            break
        # skip if in a -- comment
        line_start = text.rfind("\n", 0, p) + 1
        if text[line_start:p].lstrip().startswith("--"):
            i = p + len(func)
            continue
        paren = text.find("(", p + len(func))
        if paren < 0 or paren > p + len(func) + 3:
            i = p + len(func)
            continue
        j = paren + 1
        while j < len(text) and text[j].isspace():
            j += 1
        if text.startswith("_(", j):
            j += 2
            while j < len(text) and text[j].isspace():
                j += 1
        parsed = parse_string_at(text, j)
        if parsed:
            msgs.append(parsed[0].replace("\n", " ").strip())
            i = parsed[1]
        else:
            i = p + len(func)
    return msgs


def player_facing(path: Path) -> dict[str, list[str]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    return {
        "pline": find_call_strings(text, "nh.pline"),
        "verbalize": find_call_strings(text, "nh.verbalize"),
        "nh_text": find_call_strings(text, "nh.text"),
        "des_message": find_call_strings(text, "des.message"),
        "synopsis": re.findall(r'synopsis\s*=\s*"(\[[^\]]*\])"', text),
        "text_blocks": [
            t.replace("\n", " ").strip()[:120]
            for t in re.findall(r"text\s*=\s*\[\[(.*?)\]\]", text, re.S)
        ],
    }


def ui_english_leftovers(path: Path) -> list[str]:
    pf = player_facing(path)
    hits: list[str] = []
    for kind, items in pf.items():
        for s in items:
            if not s or re.search(r"[가-힣]", s):
                continue
            # code/docs macros in quest.lua
            if s.startswith("%p:") or "return(" in s:
                continue
            # commented debug in nhcore
            if s in ("RESTORED OLD GAME!", "NEW GAME!"):
                continue
            letters = sum(c.isalpha() for c in s)
            if letters < 12:
                continue
            ascii_l = sum(c.isascii() and c.isalpha() for c in s)
            if ascii_l / max(letters, 1) > 0.9:
                hits.append(f"{kind}: {s[:100]}")
    return hits


def audit(name: str) -> tuple[str, list[str]]:
    eng_p, ko_p = DAT / name, KO / name
    notes: list[str] = []
    severity = "OK"
    if not eng_p.exists() or not ko_p.exists():
        return "NEED", [f"missing pair for {name}"]

    diff = logic_diff(
        strip_to_logic(ko_p.read_text(encoding="utf-8")),
        strip_to_logic(eng_p.read_text(encoding="utf-8")),
    )
    if diff:
        severity = "NEED"
        notes.append(f"LOGIC DRIFT ({sum(1 for l in diff if l.startswith('@@'))} hunks):")
        shown = 0
        for line in diff:
            if line.startswith(("+", "-")) and not line.startswith(("+++", "---")):
                notes.append(f"  {line[:140]}")
                shown += 1
                if shown >= 20:
                    notes.append("  ...")
                    break

    ep, kp = player_facing(eng_p), player_facing(ko_p)
    for kind in ep:
        if len(ep[kind]) != len(kp[kind]):
            severity = "NEED"
            notes.append(f"MSG COUNT {kind}: EN={len(ep[kind])} KO={len(kp[kind])}")

    leftovers = ui_english_leftovers(ko_p)
    if leftovers:
        if severity == "OK":
            severity = "SOFT"
        notes.append(f"KO UI still-English ({len(leftovers)}):")
        for s in leftovers[:12]:
            notes.append(f"  {s}")

    return severity, notes


def main() -> int:
    files = sorted(p.name for p in KO.glob("*.lua") if (DAT / p.name).exists())
    print("=== Deep Lua locale audit ===\n")
    need = soft = 0
    for name in files:
        sev, notes = audit(name)
        if sev == "OK":
            print(f"[OK]   {name}")
            continue
        if sev == "NEED":
            need += 1
            tag = "NEED"
        else:
            soft += 1
            tag = "SOFT"
        print(f"[{tag}] {name}")
        for n in notes:
            print(f"  {n}")
        print()
    print(f"=== NEED={need} SOFT={soft} / {len(files)} ===")
    print("Tip: line-count sync alone misses these; run after every upstream lua touch.")
    return 1 if need else 0


if __name__ == "__main__":
    sys.exit(main())
