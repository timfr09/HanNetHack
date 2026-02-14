#!/usr/bin/env python3
"""
Korean verb+format combination verifier for HanNetHack.

Extracts all Tobjnam/aobjnam/Yobjnam2/otense/vtense calls with verb arguments,
looks up Korean translations in PO files, checks surrounding format strings,
and flags potential issues:
  - Dict-form verbs (사전형: ending in 다 without conjugation)
  - Copula-suppressed verbs in formats that don't provide own predicate
  - Double postpositions ({이/가} in both verb output and format)
  - Missing PO overrides for problematic format strings
"""

import re
import os
import sys
import polib
from collections import defaultdict
from pathlib import Path

# Verb functions that insert {이/가} and check copula
SUBJ_VERB_FUNCS = {'Tobjnam', 'aobjnam', 'Yobjnam2'}
# Verb functions that just return the verb form (no subject particle)
PLAIN_VERB_FUNCS = {'otense', 'vtense'}
ALL_VERB_FUNCS = SUBJ_VERB_FUNCS | PLAIN_VERB_FUNCS

COPULA_FORMS = {'이다', '이었다'}

# Patterns that are known OK and should be skipped
KNOWN_OK_VERBS = {
    'are', 'is', 'have', 'has', 'do', 'does',  # auxiliary/be verbs
}

# Known-unfixable verbs: can't change globally without C_() for each use site
# These are tracked as KNOWN issues and shown separately in the report
KNOWN_UNFIXABLE = {
    ('', 'glow'):       '"glow"→"빛나다" 공유 msgid, "%s %s." 46파일 공유 — C_() 필요',
    ('', 'softly glow'): '"softly glow"→"은은하게 빛난다" 현재형 — 문맥상 자연스러움',
    ('', 'burn'):       '"burn" transitive/intransitive 충돌 — Known Issue',
    ('', 'feel'):       '"feel"→"느껴진다" 현재형 — 기존 오버라이드로 정상 동작',
    ('', 'look'):       '"look"→"보인다" 현재형 — 문맥상 자연스러움',
    ('', 'resist'):     '"resist"→"저항한다" 현재형 — 진행 중인 저항 표현',
    ('', 'whisper'):    '"whisper"→"속삭인다" 현재형 — 진행 중인 행동 표현',
    ('', 'smell'):      '"smell"→"냄새가 난다" 현재형 — 감각 표현',
    ('', 'get'):        '"get"→"된다" 현재형 — 상태 변화 표현',
    ('', 'bounce'):     '"bounce"→"이다" 계사 억제 — 포맷 오버라이드에서 "튕겨" 제공',
    ('', 'move'):       '"move"→"움직이다" — "%s %s%s." 46파일 공유, 포맷 오버라이드 불가',
}


def load_po_translations(po_path):
    """Load PO file and return dict of (msgctxt, msgid) -> msgstr."""
    translations = {}
    po = polib.pofile(po_path)
    for entry in po:
        if entry.msgstr and not entry.obsolete:
            key = (entry.msgctxt or '', entry.msgid)
            translations[key] = entry.msgstr
    return translations


def merge_translations(ko_po_path, ko_manual_path):
    """Merge ko.po and ko_manual.po (manual takes priority)."""
    base = load_po_translations(ko_po_path)
    manual = load_po_translations(ko_manual_path)
    merged = {**base, **manual}
    return merged


def find_verb_calls(src_dir):
    """
    Parse all .c files in src/ to find verb function calls.
    Returns list of dicts with:
      - file, line, func, verb_msgid, verb_context, format_msgid, format_context, raw_line
    """
    results = []

    # Pattern for function calls: FuncName(args, _("verb")) or FuncName(args, C_("ctx", "verb"))
    # We need to handle multi-line calls too
    func_pattern = re.compile(
        r'\b(' + '|'.join(ALL_VERB_FUNCS) + r')\s*\('
    )

    for c_file in sorted(Path(src_dir).glob('*.c')):
        with open(c_file, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
            lines = content.split('\n')

        # Join continued lines for multi-line statement parsing
        joined = []
        i = 0
        while i < len(lines):
            line = lines[i]
            start_line = i + 1  # 1-indexed
            # Accumulate continuation lines
            while i < len(lines) - 1 and not line.rstrip().endswith(';') and not line.rstrip().endswith('{') and not line.rstrip().endswith('}'):
                i += 1
                line += ' ' + lines[i].strip()
                if line.count('(') <= line.count(')') and (line.rstrip().endswith(';') or line.rstrip().endswith(')') or line.rstrip().endswith(',')):
                    break
            joined.append((start_line, line))
            i += 1

        for line_no, line in joined:
            for m in func_pattern.finditer(line):
                func_name = m.group(1)
                # Extract the full function call
                call_start = m.start()
                # Find matching paren
                depth = 0
                pos = m.end() - 1  # position of opening paren
                call_end = pos
                for ci in range(pos, len(line)):
                    if line[ci] == '(':
                        depth += 1
                    elif line[ci] == ')':
                        depth -= 1
                        if depth == 0:
                            call_end = ci + 1
                            break

                call_text = line[call_start:call_end]

                # Extract verb argument (last argument before closing paren)
                verb_info = extract_verb_arg(call_text, func_name)
                if not verb_info:
                    continue

                verb_msgid, verb_context = verb_info

                # Find the surrounding format string (pline, Your, pline_The, etc.)
                format_info = extract_format_context(line, call_start)

                results.append({
                    'file': c_file.name,
                    'line': line_no,
                    'func': func_name,
                    'verb_msgid': verb_msgid,
                    'verb_context': verb_context,
                    'format_msgid': format_info[0] if format_info else None,
                    'format_context': format_info[1] if format_info else None,
                    'raw_line': line.strip()[:200],
                })

    return results


def extract_verb_arg(call_text, func_name):
    """
    Extract the verb argument from a function call like:
      Tobjnam(obj, _("verb"))
      Tobjnam(obj, C_("ctx", "verb"))
    Returns (msgid, context) or None.
    """
    # Look for _("...") or C_("...", "...") in the call
    # The verb is typically the last _() or C_() argument

    # Try C_() first
    c_match = re.search(r'C_\(\s*"([^"]*?)"\s*,\s*"([^"]*?)"\s*\)', call_text)
    if c_match:
        return (c_match.group(2), c_match.group(1))

    # Try _()
    underscore_matches = list(re.finditer(r'_\(\s*"([^"]*?)"\s*\)', call_text))
    if underscore_matches:
        # For Tobjnam/aobjnam/Yobjnam2: verb is the last _() argument
        # For otense/vtense: verb is also the last _() argument
        last_match = underscore_matches[-1]
        return (last_match.group(1), '')

    return None


def extract_format_context(line, call_start):
    """
    Find the enclosing pline/Your/pline_The format string.
    Returns (format_msgid, format_context) or None.
    """
    # Look backwards from call_start for pline(_("..."), or similar
    # Common patterns:
    #   pline(_("format"), ...)
    #   pline(C_("ctx", "format"), ...)
    #   Your(_("format"), ...)
    #   pline_The(_("format"), ...)
    #   There(_("format"), ...)

    prefix = line[:call_start]

    # Try C_() format
    c_matches = list(re.finditer(r'(?:pline|pline_The|Your|You|There|Sprintf|Strcpy)\s*\(\s*C_\(\s*"([^"]*?)"\s*,\s*"([^"]*?)"\s*\)', prefix))
    if c_matches:
        last = c_matches[-1]
        return (last.group(2), last.group(1))

    # Try _() format
    u_matches = list(re.finditer(r'(?:pline|pline_The|Your|You|There|Sprintf|Strcpy)\s*\(\s*_\(\s*"([^"]*?)"\s*\)', prefix))
    if u_matches:
        last = u_matches[-1]
        return (last.group(1), '')

    # Also check if format is after the verb call (less common but possible)
    suffix = line[call_start:]
    # Sometimes the verb call IS the first argument to pline
    # Check the whole line
    c_matches = list(re.finditer(r'(?:pline|pline_The|Your|You|There|Sprintf|Strcpy)\s*\(\s*C_\(\s*"([^"]*?)"\s*,\s*"([^"]*?)"\s*\)', line))
    if c_matches:
        return (c_matches[0].group(2), c_matches[0].group(1))

    u_matches = list(re.finditer(r'(?:pline|pline_The|Your|You|There|Sprintf|Strcpy)\s*\(\s*_\(\s*"([^"]*?)"\s*\)', line))
    if u_matches:
        return (u_matches[0].group(1), '')

    return None


def translate_verb(verb_msgid, verb_context, translations):
    """Look up verb translation in merged PO."""
    key = (verb_context, verb_msgid)
    if key in translations:
        return translations[key]
    # Fall back to no-context
    key = ('', verb_msgid)
    if key in translations:
        return translations[key]
    return None


def translate_format(format_msgid, format_context, translations):
    """Look up format string translation in merged PO."""
    if not format_msgid:
        return None
    key = (format_context or '', format_msgid)
    if key in translations:
        return translations[key]
    # Fall back to no-context
    key = ('', format_msgid)
    if key in translations:
        return translations[key]
    return None


def classify_verb_form(korean_verb):
    """Classify Korean verb form.
    Returns:
      None = OK (past tense, progressive, etc.)
      'present' = present tense (한다, ㄴ다, 는다) - OK for narration but flagged for review
      'dict' = dictionary form (빛나다, 미끄러지다) - needs conjugation
    """
    if not korean_verb:
        return None
    # Copula forms are intentional
    if korean_verb in COPULA_FORMS:
        return None
    if not korean_verb.endswith('다'):
        return None

    # Past tense markers → always OK
    past_endings = ['했다', '였다', '었다', '았다', '났다', '졌다', '렸다', '왔다',
                    '웠다', '랬다', '섰다', '됐다', '빴다', '렀다', '혔다', '겼다',
                    '쳤다', '쪘다', '꿨다', '갔다', '췄다', '봤다', '뒀다', '셌다',
                    '쐈다', '깼다', '쌌다', '맸다', '꼈다', '폈다', '겠다']
    for ending in past_endings:
        if korean_verb.endswith(ending):
            return None

    # Polite speech forms (습니다, ㅂ니다) → OK
    if korean_verb.endswith('니다') or korean_verb.endswith('습니다'):
        return None

    # Progressive/descriptive/potential forms → OK
    if '고 있다' in korean_verb or '기 시작' in korean_verb or '수 있다' in korean_verb:
        return None
    # Resultative "아/어 있다" → OK (남아 있다, 빠져 있다, etc.)
    if korean_verb.endswith(' 있다'):
        return None

    # Present tense forms → acceptable but flaggable
    present_endings = ['한다', '난다', '진다', '는다', '인다', '된다', '린다',
                       '든다', '간다', '온다', '른다', '운다', '언다', '킨다',
                       '민다', '신다', '핀다', '빈다', '긴다']
    for ending in present_endings:
        if korean_verb.endswith(ending):
            return 'present'

    # Dictionary form (빛나다, 미끄러지다, 움직이다, 떨어지다, 걷다, etc.)
    return 'dict'


def format_has_predicate(format_ko):
    """Check if a Korean format string provides its own predicate (verb/adjective ending)."""
    if not format_ko:
        return False  # unknown
    # Remove format specifiers
    cleaned = re.sub(r'%[0-9$]*\.?[0-9]*[sdf]', '', format_ko)
    cleaned = re.sub(r'\{[^}]*\}', '', cleaned)  # remove postposition markers
    cleaned = cleaned.strip().rstrip('!.?')
    if not cleaned:
        return False
    # Check for verb endings
    verb_endings = ['다', '었다', '했다', '인다', '는다', '지다', '졌다', '된다', '한다',
                    '나다', '났다', '렸다', '왔다', '셨다', '었다', '습니다']
    for ending in verb_endings:
        if cleaned.endswith(ending):
            return True
    return False


def check_double_postposition(format_ko):
    """Check if format string contains {이/가} which would duplicate with Tobjnam's {이/가}."""
    if not format_ko:
        return False
    # Count {이/가} occurrences
    return format_ko.count('{이/가}') > 0


def count_format_users(format_msgid, src_dir):
    """Count how many files use a given format string."""
    if not format_msgid:
        return 0
    # Escape for regex
    escaped = re.escape(format_msgid)
    count = 0
    for c_file in Path(src_dir).glob('*.c'):
        with open(c_file, 'r', encoding='utf-8', errors='replace') as f:
            if format_msgid in f.read():
                count += 1
    return count


def verb_suppressed_in_format(format_ko, func, call):
    """Check if the verb is suppressed by %.0s in the format string."""
    if not format_ko:
        return False
    # For otense/vtense, they're usually the 2nd or later %s argument
    # Check if any %.0s exists that could suppress the verb
    # This is a heuristic - we check if the format has fewer visible %s than the English format
    if '%.0s' in format_ko or '%2$.0s' in format_ko or '%3$.0s' in format_ko or '%4$.0s' in format_ko:
        return True  # Some argument is suppressed; may be the verb
    return False


def analyze_calls(calls, translations, src_dir):
    """Analyze all verb calls and flag issues."""
    issues = []

    for call in calls:
        verb_msgid = call['verb_msgid']
        verb_context = call['verb_context']
        func = call['func']

        # Skip known OK verbs (be/have/do)
        if verb_msgid in KNOWN_OK_VERBS:
            continue

        verb_ko = translate_verb(verb_msgid, verb_context, translations)
        format_ko = translate_format(call['format_msgid'], call['format_context'], translations)

        call_issues = []
        verb_form = classify_verb_form(verb_ko) if verb_ko else None
        is_known = (verb_context, verb_msgid) in KNOWN_UNFIXABLE or ('', verb_msgid) in KNOWN_UNFIXABLE

        # Check 1: Dict-form or present-tense verb
        if verb_form:
            suppressed = verb_suppressed_in_format(format_ko, func, call)
            if verb_form == 'dict':
                if suppressed:
                    pass  # Verb is suppressed in format, dict form doesn't matter
                elif is_known:
                    reason = KNOWN_UNFIXABLE.get((verb_context, verb_msgid)) or KNOWN_UNFIXABLE.get(('', verb_msgid))
                    call_issues.append(f'KNOWN: {reason}')
                elif func in SUBJ_VERB_FUNCS:
                    call_issues.append(
                        f'DICT-FORM: "{verb_msgid}" → "{verb_ko}" (사전형 — Tobjnam 출력에 그대로 노출)'
                    )
                else:
                    call_issues.append(
                        f'DICT-FORM: "{verb_msgid}" → "{verb_ko}" (사전형 — format %s에 노출 가능)'
                    )
            elif verb_form == 'present':
                if is_known:
                    reason = KNOWN_UNFIXABLE.get((verb_context, verb_msgid)) or KNOWN_UNFIXABLE.get(('', verb_msgid))
                    call_issues.append(f'KNOWN: {reason}')
                elif func in SUBJ_VERB_FUNCS and not suppressed:
                    call_issues.append(
                        f'PRESENT: "{verb_msgid}" → "{verb_ko}" (현재형 — 과거형 필요 여부 확인)'
                    )

        # Check 2: Copula suppression without predicate (only for subject-verb funcs)
        if func in SUBJ_VERB_FUNCS and verb_ko and verb_ko in COPULA_FORMS:
            if is_known:
                reason = KNOWN_UNFIXABLE.get((verb_context, verb_msgid)) or KNOWN_UNFIXABLE.get(('', verb_msgid))
                call_issues.append(f'KNOWN: {reason}')
            elif call['format_msgid']:
                if format_ko:
                    if not format_has_predicate(format_ko):
                        call_issues.append(
                            f'NO-PREDICATE: "{verb_msgid}" 계사 억제, format → "{format_ko}" 술어 없음'
                        )
                else:
                    call_issues.append(
                        f'COPULA-NO-OVERRIDE: "{verb_msgid}" 계사 억제, format "{call["format_msgid"]}" 한국어 오버라이드 없음'
                    )

        # Check 3: Double postposition
        if func in SUBJ_VERB_FUNCS and format_ko and check_double_postposition(format_ko):
            call_issues.append(
                f'DOUBLE-PP: format → "{format_ko}" 에 {{이/가}} 포함 — Tobjnam의 {{이/가}}와 중복 가능'
            )

        # Check 4: No translation at all
        if verb_ko is None and verb_msgid not in KNOWN_OK_VERBS:
            call_issues.append(f'NO-TRANSLATION: "{verb_msgid}" 한국어 번역 없음')

        if call_issues:
            issues.append({
                'call': call,
                'verb_ko': verb_ko,
                'format_ko': format_ko,
                'verb_form': verb_form,
                'issues': call_issues,
            })

    return issues


def print_report(issues, translations, src_dir):
    """Print a formatted report of all issues."""
    if not issues:
        print("✅ No issues found!")
        return

    # Group by issue type
    by_type = defaultdict(list)
    for item in issues:
        for issue_str in item['issues']:
            issue_type = issue_str.split(':')[0]
            by_type[issue_type].append(item)

    print(f"{'='*80}")
    print(f"Korean Verb+Format Verification Report")
    print(f"{'='*80}")
    print(f"Total issues: {len(issues)}")
    print()

    issue_order = ['NO-PREDICATE', 'COPULA-NO-OVERRIDE', 'DICT-FORM', 'DOUBLE-PP',
                    'PRESENT', 'NO-TRANSLATION', 'KNOWN']
    for issue_type in issue_order:
        items = by_type.get(issue_type, [])
        if not items:
            continue

        severity = {'NO-PREDICATE': 'CRITICAL', 'COPULA-NO-OVERRIDE': 'CRITICAL',
                     'DICT-FORM': 'HIGH', 'DOUBLE-PP': 'MEDIUM',
                     'PRESENT': 'LOW', 'NO-TRANSLATION': 'INFO', 'KNOWN': 'SKIP'}
        sev = severity.get(issue_type, 'INFO')

        print(f"\n{'─'*80}")
        print(f"[{sev}] [{issue_type}] — {len(items)} issue(s)")
        print(f"{'─'*80}")

        for item in items:
            call = item['call']
            print(f"\n  {call['file']}:{call['line']}  {call['func']}(_, \"{call['verb_msgid']}\")")
            if call['verb_context']:
                print(f"    verb context: C_(\"{call['verb_context']}\", \"{call['verb_msgid']}\")")
            print(f"    verb KO: \"{item['verb_ko']}\"")
            if call['format_msgid']:
                print(f"    format EN: \"{call['format_msgid']}\"")
                if call['format_context']:
                    print(f"    format ctx: \"{call['format_context']}\"")
                if item['format_ko']:
                    print(f"    format KO: \"{item['format_ko']}\"")
                else:
                    print(f"    format KO: (no override)")
            for issue_str in item['issues']:
                print(f"    ⚠ {issue_str}")

    # Summary
    print(f"\n{'='*80}")
    print("Summary by severity:")
    for issue_type in issue_order:
        count = len(by_type.get(issue_type, []))
        if count:
            severity = {'NO-PREDICATE': 'CRITICAL', 'COPULA-NO-OVERRIDE': 'CRITICAL',
                         'DICT-FORM': 'HIGH', 'DOUBLE-PP': 'MEDIUM',
                         'PRESENT': 'LOW', 'NO-TRANSLATION': 'INFO'}
            sev = severity.get(issue_type, 'INFO')
            print(f"  [{sev}] {issue_type}: {count}")
    print(f"{'='*80}")

    # Deduplicated verb list for quick reference
    print("\nUnique verbs with issues:")
    seen = set()
    for item in issues:
        call = item['call']
        key = (call['verb_msgid'], call['verb_context'], item['verb_ko'])
        if key not in seen:
            seen.add(key)
            ctx = f' [C_("{call["verb_context"]}")]' if call['verb_context'] else ''
            print(f'  "{call["verb_msgid"]}"{ctx} → "{item["verb_ko"]}"')


def main():
    base_dir = Path(__file__).resolve().parent.parent
    src_dir = base_dir / 'src'
    po_dir = base_dir / 'po'

    ko_po = po_dir / 'ko.po'
    ko_manual = po_dir / 'ko_manual.po'

    if not ko_po.exists() or not ko_manual.exists():
        print(f"Error: PO files not found in {po_dir}")
        sys.exit(1)

    print("Loading translations...")
    translations = merge_translations(str(ko_po), str(ko_manual))
    print(f"  Loaded {len(translations)} translation entries")

    print("Scanning source files...")
    calls = find_verb_calls(str(src_dir))
    print(f"  Found {len(calls)} verb function calls")

    print("Analyzing...")
    issues = analyze_calls(calls, translations, str(src_dir))

    print()
    print_report(issues, translations, str(src_dir))


if __name__ == '__main__':
    main()
