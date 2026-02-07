#!/usr/bin/env python3
"""
Extract translatable strings from NetHack Lua files.
Generates a POT file that can be merged with the main nethack.pot.

Patterns extracted:
- text = "..." or text = [[...]]
- synopsis = "..."
- des.message("...")
- des.engraving({ ... text = "..." ... })
- String arrays (angel_cuss, demon_cuss, etc.)

Usage:
    python3 extract_lua_strings.py [lua_files...] > lua_strings.pot
"""

import re
import sys
import os
from datetime import datetime

def escape_string(s):
    """Escape string for PO file format."""
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n"\n"')
    return s

def is_format_documentation(text):
    """Check if text is format placeholder documentation (should be skipped)."""
    # Skip format documentation blocks
    if '%p:' in text and 'return' in text:
        return True
    if text.strip().startswith('%') and ':' in text and 'return' in text:
        return True
    return False

def extract_from_lua(filepath):
    """Extract translatable strings from a Lua file."""
    strings = []

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')

    # Track line numbers
    line_num = 0
    in_multiline = False
    multiline_start = 0
    multiline_content = []
    multiline_field = None

    # Pattern for single-line text/synopsis assignments
    single_pattern = re.compile(r'(text|synopsis)\s*=\s*"([^"]*)"')

    # Pattern for multi-line text with [[ ]]
    multiline_start_pattern = re.compile(r'(text|synopsis)\s*=\s*\[\[(.*)$')
    multiline_end_pattern = re.compile(r'^(.*?)\]\]')

    # Pattern for des.message("...")
    message_pattern = re.compile(r'des\.message\s*\(\s*"([^"]+)"')

    # Pattern for array strings like in angel_cuss, demon_cuss
    array_string_pattern = re.compile(r'^\s*"([^"]+)"')

    # Detect if we're inside a known string array
    in_array = False
    array_name = None
    array_pattern = re.compile(r'^\s*(\w+)\s*=\s*\{')
    array_end_pattern = re.compile(r'^\s*\}')

    # Known translatable arrays
    translatable_arrays = {'angel_cuss', 'demon_cuss'}

    for i, line in enumerate(lines):
        line_num = i + 1

        # Skip comments
        if line.strip().startswith('--'):
            continue

        # Check for array start
        array_match = array_pattern.match(line)
        if array_match:
            name = array_match.group(1)
            if name in translatable_arrays:
                in_array = True
                array_name = name
            continue

        # Check for array end
        if in_array and array_end_pattern.match(line):
            in_array = False
            array_name = None
            continue

        # Extract strings from known arrays
        if in_array:
            arr_match = array_string_pattern.match(line)
            if arr_match:
                text = arr_match.group(1)
                if text.strip() and not is_format_documentation(text):
                    strings.append({
                        'file': filepath,
                        'line': line_num,
                        'text': text,
                        'context': f'{array_name} array'
                    })
            continue

        # Handle multi-line strings
        if in_multiline:
            end_match = multiline_end_pattern.search(line)
            if end_match:
                multiline_content.append(end_match.group(1))
                full_text = '\n'.join(multiline_content)
                if full_text.strip() and not is_format_documentation(full_text):
                    strings.append({
                        'file': filepath,
                        'line': multiline_start,
                        'text': full_text,
                        'context': f'{multiline_field} field'
                    })
                in_multiline = False
                multiline_content = []
            else:
                multiline_content.append(line)
            continue

        # Check for multi-line start
        ml_match = multiline_start_pattern.search(line)
        if ml_match:
            in_multiline = True
            multiline_start = line_num
            multiline_field = ml_match.group(1)
            initial_content = ml_match.group(2)
            if ']]' in initial_content:
                # Single line with [[ and ]]
                text = initial_content.split(']]')[0]
                if text.strip() and not is_format_documentation(text):
                    strings.append({
                        'file': filepath,
                        'line': line_num,
                        'text': text,
                        'context': f'{multiline_field} field'
                    })
                in_multiline = False
            else:
                multiline_content = [initial_content]
            continue

        # Check for single-line text/synopsis (including inside des.engraving)
        for single_match in single_pattern.finditer(line):
            field = single_match.group(1)
            text = single_match.group(2)
            # Skip if it contains Lua concatenation (has .. in the line context)
            line_context = line[max(0, single_match.start()-10):min(len(line), single_match.end()+10)]
            if '..' in line and text:
                # String with concatenation - extract the static part
                # This is a partial string, mark it as such
                if text.strip() and not is_format_documentation(text):
                    strings.append({
                        'file': filepath,
                        'line': line_num,
                        'text': text,
                        'context': f'{field} field (partial, has concatenation)'
                    })
            elif text.strip() and not is_format_documentation(text):
                strings.append({
                    'file': filepath,
                    'line': line_num,
                    'text': text,
                    'context': f'{field} field'
                })

        # Check for des.message
        for msg_match in message_pattern.finditer(line):
            text = msg_match.group(1)
            if text.strip() and not is_format_documentation(text):
                strings.append({
                    'file': filepath,
                    'line': line_num,
                    'text': text,
                    'context': 'des.message'
                })

    return strings

def generate_pot(strings, output=sys.stdout):
    """Generate POT file from extracted strings."""
    now = datetime.now().strftime('%Y-%m-%d %H:%M%z')

    header = f'''# Translatable strings extracted from NetHack Lua files.
# Copyright (C) 2026 HanNetHack Project
# This file is distributed under the same license as NetHack.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: NetHack 3.7\\n"
"Report-Msgid-Bugs-To: hannethack@example.com\\n"
"POT-Creation-Date: {now}\\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"
"Last-Translator: HanNetHack Project\\n"
"Language-Team: Korean\\n"
"Language: \\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"

'''

    output.write(header)

    # Group by msgid to avoid duplicates
    seen = {}
    for s in strings:
        msgid = s['text']
        if msgid not in seen:
            seen[msgid] = []
        seen[msgid].append(s)

    for msgid, occurrences in seen.items():
        # Write references
        for occ in occurrences:
            rel_path = os.path.relpath(occ['file'], start=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            output.write(f"#: {rel_path}:{occ['line']}\n")

        # Write context as comment
        contexts = set(occ['context'] for occ in occurrences)
        if contexts:
            output.write(f"#. {', '.join(contexts)}\n")

        # Check if multiline
        if '\n' in msgid:
            output.write('msgid ""\n')
            lines = msgid.split('\n')
            for i, line in enumerate(lines):
                if i < len(lines) - 1:
                    output.write(f'"{escape_string(line)}\\n"\n')
                else:
                    output.write(f'"{escape_string(line)}"\n')
        else:
            output.write(f'msgid "{escape_string(msgid)}"\n')

        output.write('msgstr ""\n\n')

def main():
    if len(sys.argv) < 2:
        # Default: process all Lua files in dat/
        import glob
        script_dir = os.path.dirname(os.path.abspath(__file__))
        dat_dir = os.path.join(os.path.dirname(script_dir), 'dat')
        lua_files = glob.glob(os.path.join(dat_dir, '*.lua'))
    else:
        lua_files = sys.argv[1:]

    all_strings = []
    for filepath in lua_files:
        if os.path.exists(filepath):
            strings = extract_from_lua(filepath)
            all_strings.extend(strings)
            print(f"# Extracted {len(strings)} strings from {os.path.basename(filepath)}", file=sys.stderr)

    print(f"# Total: {len(all_strings)} strings from {len(lua_files)} files", file=sys.stderr)

    generate_pot(all_strings)

if __name__ == '__main__':
    main()
