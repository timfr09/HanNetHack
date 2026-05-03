# NetHack 3.7 Translation Makefile
# Copyright (c) HanNetHack Project, 2026
# NetHack may be freely redistributed. See license for details.

# Tools
XGETTEXT = xgettext
MSGMERGE = msgmerge
MSGFMT = msgfmt
MSGINIT = msginit
MSGCAT = msgcat
PYTHON = python3

# Directories
SRCDIR = ../src
INCDIR = ../include
WINDIR = ../win
DATDIR = ../dat
UTILDIR = ../util

# Output files
DOMAIN = nethack
POTFILE = $(DOMAIN).pot
LUA_POTFILE = lua_strings.pot
LANGUAGES = ko

# Source files to extract strings from (C files)
# sys/unix, sys/share: portability shell/panic/suspend messages (not under src/)
SOURCES = $(wildcard $(SRCDIR)/*.c) \
          $(wildcard $(WINDIR)/tty/*.c) \
          $(wildcard $(WINDIR)/curses/*.c) \
          $(wildcard $(WINDIR)/win32/*.c) \
          $(wildcard ../sys/unix/*.c) \
          $(wildcard ../sys/share/*.c)

# Lua files that have Korean locale versions (dat/locale/ko/*.lua)
# These are translated directly in the locale files, not via PO
KO_LOCALE_LUA = $(addprefix $(DATDIR)/, $(notdir $(wildcard $(DATDIR)/locale/ko/*.lua)))

# Lua files to extract strings from (exclude Korean locale files)
LUA_SOURCES = $(filter-out $(KO_LOCALE_LUA), $(wildcard $(DATDIR)/*.lua))

# xgettext options for C files
XGETTEXT_OPTS = --keyword=_ --keyword=N_ \
                --keyword=C_:1c,2 \
                --from-code=UTF-8 \
                --add-comments=TRANSLATORS: \
                --package-name=NetHack \
                --package-version=3.7 \
                --msgid-bugs-address=hannethack@example.com \
                --copyright-holder="HanNetHack Project"

.PHONY: all pot pot-lua update-po compile clean stats help merge migrate verify

all: compile

# Generate POT template from all source files (C + Lua)
pot: pot-c pot-lua
	@echo "Merging C and Lua POT files..."
	$(MSGCAT) -o $(POTFILE) $(POTFILE).c $(LUA_POTFILE)
	@rm -f $(POTFILE).c
	@echo "Generated $(POTFILE) with $$(grep -c '^msgid' $(POTFILE) || echo 0) strings"

# Generate POT from C source files only
pot-c: $(SOURCES)
	@echo "Extracting translatable strings from C files..."
	$(XGETTEXT) $(XGETTEXT_OPTS) -o $(POTFILE).c $(SOURCES)
	@# Fix charset in generated POT
	@sed -i 's/charset=CHARSET/charset=UTF-8/' $(POTFILE).c
	@echo "Extracted $$(grep -c '^msgid' $(POTFILE).c || echo 0) strings from C files"

# Generate POT from Lua files
pot-lua: $(LUA_SOURCES)
	@echo "Extracting translatable strings from Lua files..."
	$(PYTHON) extract_lua_strings.py $(LUA_SOURCES) > $(LUA_POTFILE) 2>/dev/null || \
		$(PYTHON) extract_lua_strings.py > $(LUA_POTFILE)
	@echo "Extracted $$(grep -c '^msgid' $(LUA_POTFILE) || echo 0) strings from Lua files"

# Initialize a new translation file
%.po:
	@if [ ! -f $@ ]; then \
		echo "Creating new translation file: $@"; \
		$(MSGINIT) -i $(POTFILE) -o $@ -l $* --no-translator; \
	fi

# Update existing PO files from POT (only auto-extracted strings)
# Manual entries in *_manual.po are preserved separately
# WARNING: This can modify ko.po! Use 'make safe-update' instead for safety.
update-po: $(POTFILE)
	@for lang in $(LANGUAGES); do \
		if [ -f $$lang.po ]; then \
			echo "Updating $$lang.po (auto-extracted strings only)..."; \
			$(MSGMERGE) --no-fuzzy-matching -U $$lang.po $(POTFILE); \
			echo "Note: Manual entries in $${lang}_manual.po are preserved."; \
		else \
			echo "Creating $$lang.po..."; \
			$(MSGINIT) -i $(POTFILE) -o $$lang.po -l $$lang --no-translator; \
		fi \
	done

# Safe update with automatic backup
safe-update: $(POTFILE)
	@for lang in $(LANGUAGES); do \
		if [ -f $$lang.po ]; then \
			echo "=== Safe Update for $$lang.po ==="; \
			backup="$$lang.po.backup.$$(date +%Y%m%d_%H%M%S)"; \
			cp $$lang.po $$backup; \
			echo "Backed up to $$backup"; \
			$(MSGMERGE) --no-fuzzy-matching -U $$lang.po $(POTFILE); \
			changed=$$(diff -q $$lang.po $$backup 2>/dev/null || echo "changed"); \
			if [ -n "$$changed" ]; then \
				echo "WARNING: $$lang.po was modified. Review changes with:"; \
				echo "  diff $$backup $$lang.po"; \
			else \
				rm $$backup; \
				echo "No changes to $$lang.po"; \
			fi \
		fi \
	done

# Migrate ALL translated entries to ko_manual.po for permanent protection
# This ensures no translations are lost when update-po modifies ko.po
migrate: merge
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_merged.po ]; then \
			echo "=== Migrating all translations to $${lang}_manual.po ==="; \
			cp $${lang}_manual.po $${lang}_manual.po.pre-migrate; \
			msgattrib --translated $${lang}_merged.po -o $${lang}_manual_new.po; \
			new_count=$$($(MSGFMT) --statistics $${lang}_manual_new.po 2>&1 | grep -oP '^\d+'); \
			old_count=$$($(MSGFMT) --statistics $${lang}_manual.po 2>&1 | grep -oP '^\d+'); \
			if [ "$$new_count" -ge "$$old_count" ]; then \
				mv $${lang}_manual_new.po $${lang}_manual.po; \
				echo "Migrated: $$old_count -> $$new_count translated entries"; \
				echo "Backup saved: $${lang}_manual.po.pre-migrate"; \
			else \
				echo "ERROR: New file has fewer entries ($$new_count < $$old_count). Aborting."; \
				rm -f $${lang}_manual_new.po; \
			fi \
		fi \
	done

# Verify that merged translations haven't decreased after an operation
verify: merge
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_merged.po ]; then \
			count=$$($(MSGFMT) --statistics $${lang}_merged.po 2>&1 | grep -oP '^\d+'); \
			manual_count=$$($(MSGFMT) --statistics $${lang}_manual.po 2>&1 | grep -oP '^\d+'); \
			echo "=== Verification: $$lang ==="; \
			echo "  ko_manual.po: $$manual_count translated"; \
			echo "  ko_merged.po: $$count translated"; \
			if [ "$$count" -lt "$$manual_count" ]; then \
				echo "  WARNING: Merged has fewer entries than manual! Check for issues."; \
			else \
				echo "  OK: All manual translations preserved in merge."; \
			fi \
		fi \
	done

# Merge auto-extracted and manual entries into <lang>_merged.po.
#
# ko_manual.po is the canonical source of Korean translations and is
# the only PO file committed to the repository.  ko.po is treated as
# a local cache: `make update-po` (or `make safe-update`) regenerates
# it from the POT template so translators can inspect/fill untranslated
# strings, but it is *not* required for a build.  If ko.po happens to
# exist locally, its entries fill gaps that ko_manual.po hasn't covered
# (ko_manual.po always wins when both define the same msgid).
merge:
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_manual.po ] && [ -f $$lang.po ]; then \
			echo "Merging $${lang}_manual.po + $$lang.po -> $${lang}_merged.po"; \
			echo "(Manual entries take priority over auto-extracted)"; \
			$(MSGCAT) --use-first -o $${lang}_merged.po $${lang}_manual.po $$lang.po; \
		elif [ -f $${lang}_manual.po ]; then \
			echo "Using $${lang}_manual.po directly -> $${lang}_merged.po"; \
			cp $${lang}_manual.po $${lang}_merged.po; \
		elif [ -f $$lang.po ]; then \
			echo "No manual file found, using $$lang.po directly"; \
			cp $$lang.po $${lang}_merged.po; \
		else \
			echo "ERROR: neither $${lang}_manual.po nor $$lang.po exist" >&2; \
			exit 1; \
		fi \
	done

# Compile PO files to MO files
# Uses merged file if manual entries exist
# Copies the compiled catalog to ../dat/locale/<lang>/nethack.mo so
# the nhdat DLB build can pick it up (src/mo_reader.c looks it up at
# that path via dlb_fopen).
compile: merge $(LANGUAGES:=.mo)
	@for lang in $(LANGUAGES); do \
		if [ -f $$lang.mo ]; then \
			mkdir -p ../dat/locale/$$lang; \
			cp $$lang.mo ../dat/locale/$$lang/nethack.mo; \
			echo "Copied $$lang.mo to ../dat/locale/$$lang/nethack.mo"; \
		fi \
	done

%.mo: %_merged.po
	@echo "Compiling $< -> $@..."
	$(MSGFMT) -c -o $@ $<

# Fallback if no merged file
%.mo: %.po
	@if [ ! -f $*_merged.po ]; then \
		echo "Compiling $< -> $@..."; \
		$(MSGFMT) -c -o $@ $<; \
	fi

# Translation statistics
stats: merge
	@echo "=== Translation Statistics ==="
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_merged.po ]; then \
			echo ""; \
			echo "$$lang (merged):"; \
			$(MSGFMT) --statistics $${lang}_merged.po 2>&1 || true; \
		elif [ -f $$lang.po ]; then \
			echo ""; \
			echo "$$lang:"; \
			$(MSGFMT) --statistics $$lang.po 2>&1 || true; \
		fi \
	done

# Check for common translation issues
check: merge
	@echo "=== Checking translations ==="
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_merged.po ]; then \
			echo "Checking $${lang}_merged.po..."; \
			$(MSGFMT) -c -o /dev/null $${lang}_merged.po 2>&1 || true; \
		fi \
	done

# List untranslated strings
untranslated: merge
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_merged.po ]; then \
			echo "=== Untranslated in $${lang}_merged.po ==="; \
			grep -A1 'msgstr ""$$' $${lang}_merged.po | grep 'msgid' | head -20; \
		fi \
	done

# List fuzzy translations (need review)
fuzzy: merge
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_merged.po ]; then \
			echo "=== Fuzzy translations in $${lang}_merged.po ==="; \
			grep -B1 '#, fuzzy' $${lang}_merged.po | grep 'msgid' | head -20; \
		fi \
	done

# Install compiled translations
install: compile
	@for lang in $(LANGUAGES); do \
		mkdir -p $(DESTDIR)/locale/$$lang/LC_MESSAGES; \
		cp $$lang.mo $(DESTDIR)/locale/$$lang/LC_MESSAGES/$(DOMAIN).mo; \
	done

clean:
	rm -f *.mo *_merged.po *.po~ $(LUA_POTFILE) $(POTFILE).c

distclean: clean
	rm -f $(POTFILE)

help:
	@echo "NetHack Translation Makefile"
	@echo ""
	@echo "File Structure:"
	@echo "  ko_manual.po    - Canonical Korean translations (SAFE, committed)"
	@echo "  ko.po           - Local cache of auto-extracted POT entries"
	@echo "                    (NOT committed; regenerate with update-po)"
	@echo "  ko_merged.po    - Combined file (auto-generated, never edit)"
	@echo "  lua_strings.pot - Strings from Lua files (auto-generated)"
	@echo ""
	@echo "IMPORTANT: Only edit ko_manual.po."
	@echo "  - ko.po is a throwaway, rebuilt from nethack.pot"
	@echo "  - ko_manual.po entries always win the merge"
	@echo ""
	@echo "Targets:"
	@echo "  pot          - Generate POT from C + Lua files (merged)"
	@echo "  pot-c        - Generate POT from C files only"
	@echo "  pot-lua      - Generate POT from Lua files only"
	@echo "  safe-update  - Update ko.po with backup (RECOMMENDED)"
	@echo "  update-po    - Update ko.po from POT (no backup)"
	@echo "  merge        - Merge manual + auto -> merged"
	@echo "  compile      - Compile merged PO to MO file"
	@echo "  stats        - Show translation statistics"
	@echo "  check        - Check for translation errors"
	@echo "  untranslated - List untranslated strings"
	@echo "  fuzzy        - List fuzzy translations"
	@echo "  migrate      - Auto-migrate ALL translations to ko_manual.po"
	@echo "  verify       - Check no translations were lost after merge"
	@echo "  install      - Install MO files"
	@echo "  clean        - Remove generated files"
	@echo ""
	@echo "Safe Workflow:"
	@echo "  1. Edit ko_manual.po (add/fix translations)"
	@echo "  2. make compile      (merge + compile)"
	@echo "  3. make install      (copy to dat/locale)"
	@echo ""
	@echo "When adding new source strings:"
	@echo "  1. make pot          (extract from C + Lua sources)"
	@echo "  2. make safe-update  (update ko.po with backup)"
	@echo "  3. Edit ko_manual.po (add translations)"
	@echo "  4. make compile"
	@echo ""
	@echo "Lua files extracted:"
	@echo "  - dat/*.lua (quest.lua, tut-1.lua, etc.)"
	@echo "  - Patterns: text=, synopsis=, des.message(), arrays"
