/* NetHack 3.7  i18n.c  $NHDT-Date:  $  $NHDT-Branch:  $:$NHDT-Revision:  $ */
/* Copyright (c) HanNetHack Project, 2026. */
/* NetHack may be freely redistributed.  See license for details. */

#ifdef _MSC_VER
#include "win32api.h"
#endif
#include "hack.h"
#include <wchar.h>
#include <wctype.h>
#ifdef _MSC_VER
#include <io.h>
#include <stdlib.h>
#define access _access
#ifndef R_OK
#define R_OK 4
#endif
#define setenv(name, value, overwrite) _putenv_s(name, value)
/*
 * Minimal wcwidth implementation for Windows.
 * Returns 2 for CJK wide characters, 0 for control, 1 otherwise.
 */
static int
wcwidth(wchar_t wc)
{
    if (wc == 0)
        return 0;
    if (wc < 0x20 || (wc >= 0x7f && wc < 0xa0))
        return -1; /* control characters */
    /* CJK Unified Ideographs and other wide character ranges */
    if ((wc >= 0x1100 && wc <= 0x115f) ||  /* Hangul Jamo */
        wc == 0x2329 || wc == 0x232a ||
        (wc >= 0x2e80 && wc <= 0xa4cf && wc != 0x303f) || /* CJK */
        (wc >= 0xac00 && wc <= 0xd7a3) ||  /* Hangul Syllables */
        (wc >= 0xf900 && wc <= 0xfaff) ||  /* CJK Compatibility */
        (wc >= 0xfe10 && wc <= 0xfe19) ||
        (wc >= 0xfe30 && wc <= 0xfe6f) ||
        (wc >= 0xff00 && wc <= 0xff60) ||
        (wc >= 0xffe0 && wc <= 0xffe6))
        return 2;
    return 1;
}
#else
#include <unistd.h>
#endif

/*
 * UTF-8 width functions - always available regardless of ENABLE_NLS
 * These are needed for proper TTY rendering of wide characters.
 */


/*
 * Calculate display width of a UTF-8 string
 *
 * Uses wcwidth() to handle wide characters (CJK, emoji).
 * Returns the number of terminal columns needed to display the string.
 */
int
utf8_display_width(const char *utf8str)
{
    wchar_t wc;
    int width = 0;
    int len;

    if (!utf8str)
        return 0;

    /* Ensure locale is set for mbtowc */
    while (*utf8str) {
        len = mbtowc(&wc, utf8str, MB_CUR_MAX);
        if (len <= 0) {
            /* Invalid or incomplete sequence, count as 1 */
            width++;
            utf8str++;
        } else {
            int w = wcwidth(wc);
            /* wcwidth returns -1 for non-printable, treat as 1 */
            width += (w > 0) ? w : 1;
            utf8str += len;
        }
    }

    return width;
}

/*
 * Get display width of a single UTF-8 character
 *
 * Returns 1 for half-width, 2 for full-width characters.
 */
int
utf8_char_width(const char *utf8str)
{
    wchar_t wc;
    int len;
    int w;

    if (!utf8str || !*utf8str)
        return 0;

    len = mbtowc(&wc, utf8str, MB_CUR_MAX);
    if (len <= 0)
        return 1;

    w = wcwidth(wc);
    return (w > 0) ? w : 1;
}

/*
 * Translate an object name using gettext
 *
 * This function is used to translate item names like "gold piece",
 * "long sword", etc. It simply wraps the name with gettext.
 */
const char *
tr_obj_name(const char *name)
{
    if (!name || !*name)
        return name;
#ifdef ENABLE_NLS
    return gettext(name);
#else
    return name;
#endif
}

/*
 * Translate a spell name with disambiguation.
 *
 * Tries msgctxt "spell" first (for names like "light" and "knock" that
 * conflict with other meanings), then falls back to bare gettext.
 */
const char *
tr_spell_name(const char *name)
{
    if (!name || !*name)
        return name;
#ifdef ENABLE_NLS
    {
        const char *result = pgettext("spell", name);

        if (result != name)
            return result; /* found spell-specific translation */
        return gettext(name); /* fall back to bare translation */
    }
#else
    return name;
#endif
}

/*
 * Translate an effect name (wand/ring/scroll/potion) with disambiguation.
 *
 * Tries msgctxt "effect" first (for names like "light", "cold", "free action"
 * that conflict with other meanings or have context-contaminated translations),
 * then falls back to bare gettext.
 */
const char *
tr_effect_name(const char *name)
{
    if (!name || !*name)
        return name;
#ifdef ENABLE_NLS
    {
        const char *result = pgettext("effect", name);

        if (result != name)
            return result; /* found effect-specific translation */
        return gettext(name); /* fall back to bare translation */
    }
#else
    return name;
#endif
}

/*
 * Translate a food name with disambiguation.
 *
 * Tries msgctxt "food" first (for names like "orange" that conflict
 * with color adjectives), then falls back to bare gettext.
 */
const char *
tr_food_name(const char *name)
{
    if (!name || !*name)
        return name;
#ifdef ENABLE_NLS
    {
        const char *result = pgettext("food", name);

        if (result != name)
            return result; /* found food-specific translation */
        return gettext(name); /* fall back to bare translation */
    }
#else
    return name;
#endif
}

/*
 * Get localized filename for help/data files
 *
 * If a non-English locale is active, returns "locale/<lang>/<filename>".
 * The caller should use dlb_fopen to check if the file exists.
 */
const char *
get_localized_filename(const char *fname)
{
    static char buf[BUFSZ];

    if (!fname || !*fname)
        return fname;

#ifdef ENABLE_NLS
    /* For non-English locales, use locale directory */
    const char *lang = get_current_language();
    if (lang && *lang && strcmp(lang, "en") != 0) {
        snprintf(buf, sizeof(buf), "locale/%s/%s", lang, fname);
        return buf;
    }
#endif
    return fname;
}

#ifdef ENABLE_NLS

#include "i18n.h"
#include "ko_postpos.h"
#include "dlb.h"
#include "mo_reader.h"

/*
 * ------------------------------------------------------------------
 * Message catalog runtime
 *
 * HanNetHack no longer links against libintl.  Instead an XOR-
 * obfuscated catalog (locale/<lang>/nethack.mox) is shipped inside
 * the nhdat DLB and decoded on the fly by src/mo_reader.c.
 *
 * The public gettext-like helpers (nh_gettext, nh_ngettext,
 * nh_pgettext) replace the libintl exports; include/i18n.h maps the
 * classic gettext()/ngettext()/pgettext() names onto them with
 * macros so existing call sites need no changes.
 * ------------------------------------------------------------------
 */

/* Cached language info */
static char current_lang[8] = "";
static boolean korean_locale = FALSE;
static mo_catalog *g_catalog = (mo_catalog *) 0;

/*
 * Read an entire DLB-resident file into a freshly malloc()ed buffer.
 * Returns the buffer (caller takes ownership) and writes the byte
 * count to *out_len.  Returns NULL on any failure.
 */
static uint8_t *
slurp_dlb_file(const char *path, size_t *out_len)
{
    dlb *fp;
    long end;
    size_t len;
    uint8_t *buf;
    int got;

    if (!path || !*path || !out_len)
        return (uint8_t *) 0;

    fp = dlb_fopen(path, RDBMODE);
    if (!fp)
        return (uint8_t *) 0;

    if (dlb_fseek(fp, 0L, SEEK_END) != 0) {
        (void) dlb_fclose(fp);
        return (uint8_t *) 0;
    }
    end = dlb_ftell(fp);
    if (end <= 0) {
        (void) dlb_fclose(fp);
        return (uint8_t *) 0;
    }
    if (dlb_fseek(fp, 0L, SEEK_SET) != 0) {
        (void) dlb_fclose(fp);
        return (uint8_t *) 0;
    }

    len = (size_t) end;
    buf = (uint8_t *) alloc(len);
    if (!buf) {
        (void) dlb_fclose(fp);
        return (uint8_t *) 0;
    }

    got = dlb_fread((char *) buf, 1, (int) len, fp);
    (void) dlb_fclose(fp);
    if ((size_t) got != len) {
        free(buf);
        return (uint8_t *) 0;
    }

    *out_len = len;
    return buf;
}

/*
 * Attempt to load locale/<lang>/nethack.mox through the DLB layer.
 * On success installs the catalog as g_catalog and returns TRUE.
 * Any previously loaded catalog is freed regardless of outcome.
 */
static boolean
load_catalog_for_lang(const char *lang)
{
    char path[BUFSZ];
    uint8_t *buf;
    size_t len = 0;
    mo_catalog *cat;

    if (g_catalog) {
        mo_free(g_catalog);
        g_catalog = (mo_catalog *) 0;
    }
    if (!lang || !*lang || strcmp(lang, "en") == 0)
        return FALSE;

    Snprintf(path, sizeof path, "locale/%s/nethack.mox", lang);
    buf = slurp_dlb_file(path, &len);
    if (!buf)
        return FALSE;

    cat = mox_load(buf, len);
    if (!cat) {
        /* mox_load() frees the buffer on failure. */
        return FALSE;
    }
    g_catalog = cat;
    return TRUE;
}

/*
 * gettext equivalent: look up msgid in the active catalog and return
 * the translation.  On miss (or if no catalog is loaded) returns the
 * original msgid pointer so callers can safely use the result as a
 * display string.
 */
const char *
nh_gettext(const char *msgid)
{
    const char *tr;

    if (!msgid)
        return msgid;
    if (!g_catalog)
        return msgid;
    tr = mo_lookup(g_catalog, msgid);
    return tr ? tr : msgid;
}

/*
 * ngettext equivalent.  HanNetHack only ships a Korean catalog today,
 * which uses nplurals=1, so we always return the first msgstr form
 * when a translation exists.  Without a catalog we fall back to the
 * English singular/plural pair based on n.
 */
const char *
nh_ngettext(const char *msgid_singular, const char *msgid_plural,
            unsigned long int n)
{
    const char *tr;

    if (g_catalog && msgid_singular) {
        tr = mo_lookup(g_catalog, msgid_singular);
        if (tr)
            return tr;
    }
    return (n == 1UL) ? msgid_singular : msgid_plural;
}

/*
 * pgettext equivalent.  Looks up "ctx\004msgid" and falls back to the
 * bare msgid on miss.
 */
const char *
nh_pgettext(const char *msgctxt, const char *msgid)
{
    const char *tr;

    if (!msgid)
        return msgid;
    if (!msgctxt || !*msgctxt)
        return nh_gettext(msgid);
    if (!g_catalog)
        return msgid;
    tr = mo_lookup_ctx(g_catalog, msgctxt, msgid);
    return tr ? tr : msgid;
}

/*
 * Map language code to full locale name
 */
static const char *
get_locale_for_lang(const char *lang)
{
    if (!lang || !*lang)
        lang = "ko";  /* Default to Korean for HanNetHack */
#ifdef _WIN32
    /* Windows uses different locale name formats */
    if (strcmp(lang, "ko") == 0)
        return "Korean_Korea.UTF-8";
    if (strcmp(lang, "en") == 0)
        return "English_United States.UTF-8";
    if (strcmp(lang, "ja") == 0)
        return "Japanese_Japan.UTF-8";
    if (strcmp(lang, "zh") == 0)
        return "Chinese_China.UTF-8";
    return "English_United States.UTF-8";
#else
    if (strcmp(lang, "ko") == 0)
        return "ko_KR.utf8";
    if (strcmp(lang, "en") == 0)
        return "en_US.utf8";
    if (strcmp(lang, "ja") == 0)
        return "ja_JP.utf8";
    if (strcmp(lang, "zh") == 0)
        return "zh_CN.utf8";
    /* For other codes, try to construct a locale name */
    return "en_US.utf8";  /* Fallback */
#endif
}

/*
 * Set the language at runtime.
 *
 * We only need two side effects now:
 *   1. setlocale() so wcwidth/mbtowc behave sensibly for the target
 *      script (Korean TTY rendering leans on this).
 *   2. Load the obfuscated .mox catalog through the DLB so nh_gettext
 *      & friends start returning translated strings.
 */
void
set_language(const char *lang)
{
    const char *locale_name;
    char *loc_result;

    if (!lang || !*lang)
        lang = "ko";  /* Default to Korean for HanNetHack */

    /* Get the full locale name for this language and install it. */
    locale_name = get_locale_for_lang(lang);
    loc_result = setlocale(LC_ALL, locale_name);
    if (!loc_result)
        loc_result = setlocale(LC_ALL, "");
    if (!loc_result)
        (void) setlocale(LC_ALL, "C.UTF-8");

    /* Update cached language info before loading the catalog so that
     * any failure path still leaves the language state consistent. */
    strncpy(current_lang, lang, sizeof(current_lang) - 1);
    current_lang[sizeof(current_lang) - 1] = '\0';
    korean_locale = (strcmp(current_lang, "ko") == 0);

    /* Load the obfuscated message catalog via DLB.  Failure is not
     * fatal - nh_gettext will simply echo the English msgid back. */
    (void) load_catalog_for_lang(current_lang);
}

/*
 * Initialize internationalization subsystem
 *
 * Should be called early in main() or allmain.c
 * Uses iflags.language if set, otherwise defaults to Korean.
 */
void
init_i18n(void)
{
    const char *lang;

    /* Check if language was set in options */
    if (iflags.language[0]) {
        lang = iflags.language;
    } else {
        /* Default to Korean for HanNetHack */
        lang = "ko";
        strncpy(iflags.language, lang, sizeof(iflags.language) - 1);
        iflags.language[sizeof(iflags.language) - 1] = '\0';
    }

    /* Apply the language setting */
    set_language(lang);
}

/*
 * Get current language code
 */
const char *
get_current_language(void)
{
    return current_lang[0] ? current_lang : "en";
}

/*
 * Check if current language is Korean
 */
boolean
is_korean_locale(void)
{
    return korean_locale;
}

/*
 * Process Korean postpositions in a translated string
 *
 * This function processes format strings containing postposition patterns
 * like {은/는}, {이/가}, {을/를} after variable substitution.
 *
 * Usage:
 *   char buf[BUFSZ];
 *   process_korean_postpositions(buf, "%s{을/를} 때렸다.", mon_nam(mtmp));
 *
 * The function:
 * 1. Performs sprintf-style formatting
 * 2. Scans for postposition patterns {X/Y}
 * 3. Replaces each pattern based on the preceding character's batchim
 */
char *
process_korean_postpositions(char *buf, const char *format, ...)
{
    va_list args;
    char temp[BUFSZ * 2];
    char *outp;
    const char *inp;
    ko_postpos_type pp_type;
    int pp_len;
    const char *last_char_pos;
    int last_char_len;
    ko_batchim_type batchim;

    if (!buf || !format)
        return buf;

    /* First, do standard formatting */
    va_start(args, format);
    nh_vsnprintf(temp, sizeof(temp), format, args);
    va_end(args);

    /* If not Korean locale, just copy and return */
    if (!korean_locale) {
        strncpy(buf, temp, BUFSZ - 1);
        buf[BUFSZ - 1] = '\0';
        return buf;
    }

    /* Process postposition patterns */
    outp = buf;
    inp = temp;

    while (*inp && (outp - buf) < BUFSZ - 10) {
        if (*inp == KO_PP_START) {
            /* Found potential postposition pattern */
            if (ko_parse_postposition_pattern(inp, &pp_type, &pp_len)) {
                /* Find the last character before this pattern */
                *outp = '\0';  /* Temporarily terminate for scanning */
                last_char_len = ko_find_last_char(buf, &last_char_pos);

                if (last_char_len > 0) {
                    /* Determine batchim */
                    unsigned int cp;
                    int bytes;
                    cp = utf8_to_codepoint(last_char_pos, &bytes);
                    batchim = ko_check_batchim_codepoint(cp);

                    /* If ASCII, check English pronunciation rules */
                    if (batchim == KO_BATCHIM_NONE && cp < 0x80) {
                        /* Find start of the ASCII word */
                        const char *word_start = last_char_pos;
                        while (word_start > buf && isalnum((unsigned char)*(word_start-1))) {
                            word_start--;
                        }
                        char word[64];
                        int wlen = last_char_pos + last_char_len - word_start;
                        if (wlen > 0 && wlen < (int)sizeof(word)) {
                            strncpy(word, word_start, wlen);
                            word[wlen] = '\0';
                            batchim = ko_english_batchim(word);
                        }
                    }
                } else {
                    batchim = KO_BATCHIM_NONE;
                }

                /* Get the appropriate postposition */
                const char *pp = ko_get_postposition(batchim, pp_type);
                if (pp) {
                    while (*pp && (outp - buf) < BUFSZ - 1) {
                        *outp++ = *pp++;
                    }
                }

                /* Skip the pattern in input */
                inp += pp_len;
                continue;
            }
        }

        /* Copy regular character */
        int charlen = utf8_char_len((unsigned char)*inp);
        while (charlen-- > 0 && *inp && (outp - buf) < BUFSZ - 1) {
            *outp++ = *inp++;
        }
    }

    *outp = '\0';
    return buf;
}

/*
 * Apply Korean postpositions to an already-formatted string
 *
 * This is a simpler wrapper for cases where the string is already
 * formatted and we just need to process the postposition patterns.
 * The string is modified in place.
 *
 * Usage:
 *   apply_korean_postpositions(out_line);
 */
char *
apply_korean_postpositions(char *str)
{
    char temp[BUFSZ];

    if (!str || !korean_locale)
        return str;

    /* Copy to temp buffer and process back into original */
    strncpy(temp, str, BUFSZ - 1);
    temp[BUFSZ - 1] = '\0';

    return process_korean_postpositions(str, "%s", temp);
}

#endif /* ENABLE_NLS */
