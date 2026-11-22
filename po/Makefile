# HanNetHack (NetHack 5.0) Translation Makefile
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
          $(wildcard ../sys/share/*.c) \
          $(wildcard ../sys/vms/*.c)

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
                --package-name=HanNetHack \
                --package-version=5.0 \
                --msgid-bugs-address=hannethack@example.com \
                --copyright-holder="HanNetHack Project"

.PHONY: all pot pot-lua update-po compile clean stats help merge migrate verify \
        translation-ci missing obsolete fuzzy-preview

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

# Legacy: rebuild optional local ko.po from POT.
# Prefer 'make missing' / 'make fuzzy-preview' against ko_manual.po — ko.po is
# no longer used by merge/compile (builds are always ko_manual-only).
update-po: $(POTFILE)
	@echo "NOTE: update-po is legacy. Prefer: make missing / make fuzzy-preview"
	@for lang in $(LANGUAGES); do \
		if [ -f $$lang.po ]; then \
			echo "Updating $$lang.po (local only; ignored by merge)..."; \
			$(MSGMERGE) --no-fuzzy-matching -U $$lang.po $(POTFILE); \
		else \
			echo "Creating $$lang.po (local only)..."; \
			$(MSGINIT) -i $(POTFILE) -o $$lang.po -l $$lang --no-translator; \
		fi \
	done

# Legacy alias kept for scripts/docs; same as update-po with backup.
safe-update: $(POTFILE)
	@echo "NOTE: safe-update is legacy. Prefer: make missing / make fuzzy-preview"
	@for lang in $(LANGUAGES); do \
		if [ -f $$lang.po ]; then \
			backup="$$lang.po.backup.$$(date +%Y%m%d_%H%M%S)"; \
			cp $$lang.po $$backup; \
			$(MSGMERGE) --no-fuzzy-matching -U $$lang.po $(POTFILE); \
			if diff -q $$lang.po $$backup >/dev/null 2>&1; then \
				rm $$backup; \
				echo "No changes to $$lang.po"; \
			else \
				echo "Updated $$lang.po (backup $$backup); not used by merge."; \
			fi \
		else \
			$(MAKE) update-po; \
		fi \
	done

# One-shot: copy all currently translated merged entries into ko_manual.po
# (historical helper; day-to-day work edits ko_manual.po directly)
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

# Build <lang>_merged.po from ko_manual.po only (reproducible; ignores local ko.po).
merge:
	@for lang in $(LANGUAGES); do \
		if [ -f $${lang}_manual.po ]; then \
			echo "Using $${lang}_manual.po -> $${lang}_merged.po"; \
			cp $${lang}_manual.po $${lang}_merged.po; \
		else \
			echo "ERROR: $${lang}_manual.po missing" >&2; \
			exit 1; \
		fi \
	done

# POT msgids missing from ko_manual.po (new / changed English after pot).
missing: $(POTFILE)
	@test -f ko_manual.po || (echo "ko_manual.po missing" >&2; exit 1)
	@echo "=== msgids in $(POTFILE) not defined in ko_manual.po ==="
	@msgcmp --use-untranslated ko_manual.po $(POTFILE) 2>&1 \
		| grep 'this message is used but not defined' \
		| sed 's/: this message is used but not defined.*//' \
		|| true
	@count=$$(msgcmp --use-untranslated ko_manual.po $(POTFILE) 2>&1 \
		| grep -c 'this message is used but not defined' || true); \
	echo "missing_count=$$count"

# ko_manual.po entries not present in current POT (orphans / retired strings).
obsolete: $(POTFILE)
	@test -f ko_manual.po || (echo "ko_manual.po missing" >&2; exit 1)
	@echo "=== msgids in ko_manual.po not used by $(POTFILE) ==="
	@msgcmp ko_manual.po $(POTFILE) 2>&1 \
		| grep 'warning: this message is not used' \
		| sed 's/: warning: this message is not used//' \
		|| true
	@count=$$(msgcmp ko_manual.po $(POTFILE) 2>&1 \
		| grep -c 'warning: this message is not used' || true); \
	echo "obsolete_count=$$count"

# Preview fuzzy matches without touching ko_manual.po (review aid).
fuzzy-preview: $(POTFILE)
	@test -f ko_manual.po || (echo "ko_manual.po missing" >&2; exit 1)
	@tmp=ko_manual.fuzzy-preview.po; \
	cp ko_manual.po $$tmp; \
	$(MSGMERGE) --update --backup=none $$tmp $(POTFILE); \
	echo "=== fuzzy entries in $$tmp (ko_manual.po unchanged) ==="; \
	msgattrib --only-fuzzy --no-wrap $$tmp 2>/dev/null | head -80 || true; \
	fcount=$$(msgattrib --only-fuzzy -o /dev/null $$tmp 2>&1 | grep -oE '^[0-9]+' | head -1 || echo 0); \
	echo "fuzzy_preview_count=$${fcount:-0}"; \
	echo "Inspect $$tmp then delete when done (gitignored pattern *.fuzzy-preview.po)."

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

# PR/CI: validate canonical manual PO, then merged file, print stats
translation-ci:
	@echo "=== translation-ci ==="
	@test -f ko_manual.po || (echo "ko_manual.po missing" >&2; exit 1)
	@echo "msgfmt --check on ko_manual.po"
	@$(MSGFMT) -c -o /dev/null ko_manual.po
	@$(MAKE) merge
	@echo "msgfmt --check on ko_merged.po"
	@$(MSGFMT) -c -o /dev/null ko_merged.po
	@echo ""
	@$(MSGFMT) --statistics ko_merged.po 2>&1 || true
	@echo "translation-ci: OK"

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
	@echo "HanNetHack Translation Makefile"
	@echo ""
	@echo "File Structure:"
	@echo "  ko_manual.po    - Sole canonical Korean translations (edit+commit)"
	@echo "  ko_merged.po    - Copy of manual for msgfmt (auto-generated)"
	@echo "  nethack.pot     - Template from sources (make pot)"
	@echo "  ko.po           - Legacy local file (ignored by merge/compile)"
	@echo ""
	@echo "IMPORTANT: Only edit ko_manual.po. Builds never read ko.po."
	@echo ""
	@echo "Targets:"
	@echo "  pot            - Generate POT from C + Lua files"
	@echo "  merge          - ko_manual.po -> ko_merged.po"
	@echo "  compile        - Merge + msgfmt + copy to dat/locale/ko/nethack.mo"
	@echo "  missing        - POT msgids not in ko_manual.po"
	@echo "  obsolete       - ko_manual.po msgids not in POT"
	@echo "  fuzzy-preview  - msgmerge preview (does not edit ko_manual.po)"
	@echo "  translation-ci - msgfmt -c on manual+merged (PR/CI)"
	@echo "  untranslated   - Empty msgstr in merged"
	@echo "  stats/check    - Statistics / msgfmt check"
	@echo "  safe-update    - Legacy ko.po cache (optional, unused by merge)"
	@echo ""
	@echo "Safe Workflow:"
	@echo "  1. Edit ko_manual.po"
	@echo "  2. make compile"
	@echo "  3. cd .. && make all"
	@echo ""
	@echo "After upstream / new source strings:"
	@echo "  1. make pot && make missing"
	@echo "  2. (optional) make fuzzy-preview"
	@echo "  3. Add translations to ko_manual.po"
	@echo "  4. make compile"
