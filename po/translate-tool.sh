#!/bin/bash
# NetHack Korean Translation Management Tool
# Copyright (c) HanNetHack Project, 2026

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PO_FILE="$SCRIPT_DIR/ko.po"
MANUAL_PO="$SCRIPT_DIR/ko_manual.po"
MERGED_PO="$SCRIPT_DIR/ko_merged.po"
POT_FILE="$SCRIPT_DIR/nethack.pot"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

usage() {
    echo "NetHack Korean Translation Tool"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  stats              Show translation statistics"
    echo "  search <term>      Search for strings containing <term>"
    echo "  untranslated       List untranslated strings"
    echo "  fuzzy              List fuzzy (needs review) strings"
    echo "  combo              Find combination patterns (enl_msg)"
    echo "  combo-check        Check combination pattern comments"
    echo "  verb-prefix        Check verb prefix translations"
    echo "  from-what          Check from_what() pattern translations"
    echo "  wrong              Find potentially wrong translations"
    echo "  validate           Validate translation format"
    echo "  postpos-check      Check Korean postposition patterns"
    echo "  build              Build translations (merge + compile)"
    echo "  preflight          Run make translation-ci (msgfmt checks + stats)"
    echo "  backup             Create backup of current translations"
    echo "  help               Show this help"
    echo ""
    echo "Files:"
    echo "  ko_manual.po  - Edit this file for translations (safe)"
    echo "  ko.po         - Auto-extracted (DO NOT EDIT)"
    echo "  ko_merged.po  - Combined result (auto-generated)"
    echo ""
    echo "Examples:"
    echo "  $0 stats"
    echo "  $0 search 'You hit'"
    echo "  $0 combo | head -20"
    echo "  $0 build"
}

# Show translation statistics
stats() {
    # Build merged file first
    make -s merge 2>/dev/null || true

    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    if [ ! -f "$target" ]; then
        echo -e "${RED}Error: No PO file found${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== NetHack Korean Translation Statistics ===${NC}"
    echo ""

    # Use msgfmt for accurate stats
    stats_output=$(msgfmt --statistics "$target" 2>&1)
    echo -e "From msgfmt: ${CYAN}$stats_output${NC}"
    echo ""

    total=$(grep -c '^msgid "' "$target" 2>/dev/null || echo 0)
    translated=$(grep -c '^msgstr ".' "$target" 2>/dev/null || echo 0)
    fuzzy=$(grep -c '#, fuzzy' "$target" 2>/dev/null || echo 0)

    # Manual entries
    if [ -f "$MANUAL_PO" ]; then
        manual=$(grep -c '^msgid "' "$MANUAL_PO" 2>/dev/null || echo 0)
        echo -e "Manual entries (ko_manual.po): ${GREEN}$manual${NC}"
    fi

    echo ""
    echo -e "Fuzzy (need review): ${YELLOW}$fuzzy${NC}"

    # Check for zero-width space usage
    zwsp=$(grep -c '​' "$target" 2>/dev/null || echo 0)
    echo -e "Zero-width space entries: ${CYAN}$zwsp${NC}"
}

# Search for strings
search() {
    if [ -z "$1" ]; then
        echo "Usage: $0 search <term>"
        exit 1
    fi

    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    echo -e "${BLUE}=== Searching for: $1 ===${NC}"
    grep -B2 -A2 -i "$1" "$target" | head -100
}

# List untranslated strings
untranslated() {
    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    echo -e "${BLUE}=== Untranslated Strings ===${NC}"
    msgattrib --untranslated "$target" 2>/dev/null | grep -A1 '^msgid "' | head -50
}

# List fuzzy translations
fuzzy() {
    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    echo -e "${BLUE}=== Fuzzy Translations (Need Review) ===${NC}"
    grep -B2 '#, fuzzy' "$target" | grep 'msgid "' | head -30
}

# Find combination patterns (enl_msg related)
combo() {
    echo -e "${BLUE}=== Combination Patterns (enl_msg related) ===${NC}"
    echo ""

    # Search for verb prefixes
    echo -e "${CYAN}Verb prefixes (are/were/have/had/can/could):${NC}"
    grep -E 'msgid "(are |were |have |had |can |could |is |was )"' "$MERGED_PO" "$PO_FILE" 2>/dev/null | head -20

    echo ""
    echo -e "${CYAN}Verb suffixes (ed/es/ing/s):${NC}"
    grep -E 'msgid "(ed|es|ing|s)"$' "$MERGED_PO" "$PO_FILE" 2>/dev/null | head -10

    echo ""
    echo -e "${CYAN}Partial sentences (starting with space):${NC}"
    grep -E 'msgid " [a-z]' "$MERGED_PO" "$PO_FILE" 2>/dev/null | head -20

    echo ""
    echo -e "${CYAN}from_what() patterns:${NC}"
    grep -E 'msgid " (because|from|due to|innately|intrinsically)' "$MERGED_PO" "$PO_FILE" 2>/dev/null | head -10
}

# Check combination pattern comments
combo_check() {
    echo -e "${BLUE}=== Checking Combination Pattern Comments ===${NC}"
    echo ""

    if [ ! -f "$MANUAL_PO" ]; then
        echo -e "${RED}Error: ko_manual.po not found${NC}"
        exit 1
    fi

    # Check for entries without combination comments
    echo -e "${YELLOW}Entries that might need [조합 메시지] comments:${NC}"

    # Find verb prefixes without proper comments
    awk '
    /^msgid "(are |were |have |had |can |could |is |was )"/ {
        if (prev !~ /조합|동사|prefix|verb/) {
            print NR ": " $0 " (missing combination comment)"
        }
    }
    { prev = $0 }
    ' "$MANUAL_PO" | head -20

    echo ""
    echo -e "${GREEN}Entries with proper comments:${NC}"
    grep -c '조합' "$MANUAL_PO" 2>/dev/null || echo "0"
    echo " entries have 조합 comments"
}

# Check verb prefix translations
verb_prefix() {
    echo -e "${BLUE}=== Verb Prefix Translations ===${NC}"
    echo ""

    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    prefixes=("are " "were " "was " "is " "have " "had " "can " "could " "have been " "have never ")

    for p in "${prefixes[@]}"; do
        echo -e "${CYAN}\"$p\":${NC}"
        result=$(grep -A1 "^msgid \"$p\"$" "$target" 2>/dev/null | grep msgstr || echo "  (not found)")

        # Check if it's zero-width space
        if echo "$result" | grep -q '​'; then
            echo -e "  ${GREEN}$result (zero-width space)${NC}"
        elif echo "$result" | grep -q 'msgstr ""'; then
            echo -e "  ${RED}$result (empty - will fallback to English!)${NC}"
        else
            echo "  $result"
        fi
    done
}

# Check from_what() pattern translations
from_what() {
    echo -e "${BLUE}=== from_what() Pattern Translations ===${NC}"
    echo ""

    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    patterns=(
        " because of %s"
        " from birth"
        " innately"
        " intrinsically"
        " because of your experience"
        " due to your lycanthropy"
        " from your creature form"
    )

    for p in "${patterns[@]}"; do
        echo -e "${CYAN}\"$p\":${NC}"
        grep -A1 "msgid \"$p\"" "$target" 2>/dev/null | grep msgstr || echo "  (not found)"
    done
}

# Find potentially wrong translations (fuzzy matches)
wrong() {
    echo -e "${BLUE}=== Potentially Wrong Translations ===${NC}"
    echo ""

    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    echo -e "${YELLOW}Short English strings with long Korean translations (possible wrong match):${NC}"
    awk '
    /^msgid "/ {
        gsub(/^msgid "/, ""); gsub(/"$/, "")
        msgid = $0
        msgid_len = length(msgid)
    }
    /^msgstr "/ {
        gsub(/^msgstr "/, ""); gsub(/"$/, "")
        msgstr = $0
        msgstr_len = length(msgstr)

        # Short English (<15 chars) with long Korean (>30 chars) is suspicious
        if (msgid_len > 0 && msgid_len < 15 && msgstr_len > 30) {
            print "Suspicious: \"" msgid "\" -> \"" msgstr "\""
        }
    }
    ' "$target" | head -20
}

# Validate postposition patterns
postpos_check() {
    echo -e "${BLUE}=== Checking Korean Postposition Patterns ===${NC}"
    echo ""

    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    echo "Checking for valid postposition patterns..."
    valid_patterns=('{은/는}' '{이/가}' '{을/를}' '{과/와}' '{으로/로}' '{아/야}' '{이다/다}' '{이었/였}' '{이/}')

    for pattern in "${valid_patterns[@]}"; do
        count=$(grep -c "$pattern" "$target" 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
            echo -e "  $pattern: ${GREEN}$count occurrences${NC}"
        fi
    done

    echo ""
    echo "Checking for potential issues..."

    # Check for malformed patterns
    malformed=$(grep -oE '\{[^}]+\}' "$target" 2>/dev/null | grep '/' | sort -u | grep -v -E '^\{(은/는|이/가|을/를|과/와|으로/로|아/야|이다/다|이었/였|이/)\}$' | head -10)
    if [ -n "$malformed" ]; then
        echo -e "${YELLOW}Warning: Unknown postposition patterns:${NC}"
        echo "$malformed"
    else
        echo -e "${GREEN}All postposition patterns are valid.${NC}"
    fi
}

# Build translations
build() {
    echo -e "${BLUE}=== Building Translations ===${NC}"
    echo ""

    cd "$SCRIPT_DIR"

    echo "Step 1: Merging ko_manual.po + ko.po..."
    make merge

    echo ""
    echo "Step 2: Compiling to .mo..."
    make compile

    echo ""
    echo -e "${GREEN}Build complete!${NC}"
    echo "Run 'make install' from project root to install."
}

# Same as: cd po && make translation-ci
preflight() {
    cd "$SCRIPT_DIR"
    echo -e "${BLUE}=== translation-ci (ko_manual + merged msgfmt -c) ===${NC}"
    make translation-ci
}

# Create backup
backup() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="$SCRIPT_DIR/backups"
    mkdir -p "$backup_dir"

    if [ -f "$MANUAL_PO" ]; then
        cp "$MANUAL_PO" "$backup_dir/ko_manual_$timestamp.po"
        echo -e "${GREEN}Backup created: $backup_dir/ko_manual_$timestamp.po${NC}"
    fi

    if [ -f "$PO_FILE" ]; then
        cp "$PO_FILE" "$backup_dir/ko_$timestamp.po"
        echo -e "${GREEN}Backup created: $backup_dir/ko_$timestamp.po${NC}"
    fi
}

# Validate translation format
validate() {
    echo -e "${BLUE}=== Validating Translations ===${NC}"

    make -s merge 2>/dev/null || true
    local target="$MERGED_PO"
    [ ! -f "$target" ] && target="$PO_FILE"

    # Check with msgfmt
    if command -v msgfmt &> /dev/null; then
        echo "Running msgfmt validation..."
        if msgfmt -c -o /dev/null "$target" 2>&1; then
            echo -e "${GREEN}msgfmt: OK${NC}"
        else
            echo -e "${RED}msgfmt: ERRORS${NC}"
        fi
    fi

    echo ""
    echo "Checking format string consistency..."
    awk '
    /^msgid "/ {
        msgid = $0
        gsub(/^msgid "/, "", msgid)
        gsub(/"$/, "", msgid)
        n = gsub(/%[0-9]*\$?[sdcfxl]/, "&", msgid)
        id_formats = n
        id_text = msgid
    }
    /^msgstr "/ {
        msgstr = $0
        gsub(/^msgstr "/, "", msgstr)
        gsub(/"$/, "", msgstr)
        if (msgstr != "" && msgstr != "​") {
            n = gsub(/%[0-9]*\$?[sdcfxl]/, "&", msgstr)
            if (n != id_formats && id_formats > 0) {
                print "Format mismatch:"
                print "  msgid:  " id_text " (" id_formats " formats)"
                print "  msgstr: " msgstr " (" n " formats)"
                print ""
            }
        }
    }
    ' "$target" | head -30
}

# Main
case "${1:-help}" in
    stats)
        stats
        ;;
    search)
        search "$2"
        ;;
    untranslated)
        untranslated
        ;;
    fuzzy)
        fuzzy
        ;;
    combo)
        combo
        ;;
    combo-check)
        combo_check
        ;;
    verb-prefix)
        verb_prefix
        ;;
    from-what)
        from_what
        ;;
    wrong)
        wrong
        ;;
    validate)
        validate
        ;;
    postpos-check)
        postpos_check
        ;;
    build)
        build
        ;;
    preflight)
        preflight
        ;;
    backup)
        backup
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac
