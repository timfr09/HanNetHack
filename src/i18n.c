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
#elif defined(__MINGW32__)
#include <unistd.h>
/*
 * MinGW: <wchar.h> does not declare wcwidth(); match MSVC minimal logic.
 */
static int
wcwidth(wchar_t wc)
{
    if (wc == 0)
        return 0;
    if (wc < 0x20 || (wc >= 0x7f && wc < 0xa0))
        return -1;
    if ((wc >= 0x1100 && wc <= 0x115f) || wc == 0x2329 || wc == 0x232a
        || (wc >= 0x2e80 && wc <= 0xa4cf && wc != 0x303f)
        || (wc >= 0xac00 && wc <= 0xd7a3) || (wc >= 0xf900 && wc <= 0xfaff)
        || (wc >= 0xfe10 && wc <= 0xfe19) || (wc >= 0xfe30 && wc <= 0xfe6f)
        || (wc >= 0xff00 && wc <= 0xff60) || (wc >= 0xffe0 && wc <= 0xffe6))
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

#ifdef _MSC_VER
/* Byte length of UTF-8 character starting with this lead byte (RFC 3629). */
static int
utf8_first_seq_len(unsigned char c)
{
    if (c < 0x80)
        return 1;
    if ((c & 0xe0) == 0xc0)
        return 2;
    if ((c & 0xf0) == 0xe0)
        return 3;
    if ((c & 0xf8) == 0xf0)
        return 4;
    return 1;
}

/*
 * MSVC + UTF-8 console: setlocale(LC_CTYPE) is easy to get wrong after other
 * LC_ALL tweaks; mbtowc() may fail on valid Hangul. CP_UTF8 conversion is
 * reliable for width.
 */
static int
utf8_one_wchar_msvc(const char *utf8str, wchar_t *outwc)
{
    int blen = utf8_first_seq_len((unsigned char) utf8str[0]);

    if (MultiByteToWideChar(CP_UTF8, 0, utf8str, blen, outwc, 1) != 1)
        return 0;
    return blen;
}
#endif /* _MSC_VER */

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
#ifdef _MSC_VER
        {
            int bl;

            if ((bl = utf8_one_wchar_msvc(utf8str, &wc)) > 0) {
                int w = wcwidth(wc);

                width += (w > 0) ? w : 1;
                utf8str += bl;
                continue;
            }
        }
#endif /* _MSC_VER */
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

#ifdef _MSC_VER
    if (utf8_one_wchar_msvc(utf8str, &wc)) {
        w = wcwidth(wc);
        return (w > 0) ? w : 1;
    }
#endif
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
 * Translate a defsym explanation string (terrain, trap, furniture).
 * symidx is a cmap index (S_arrow_trap, S_fountain, &c).
 */
const char *
tr_defsym_explanation(int symidx)
{
    if (symidx < 0 || symidx > MAXPCHARS)
        return "";
    if (!defsyms[symidx].explanation || !*defsyms[symidx].explanation)
        return "";
#ifdef ENABLE_NLS
    return gettext(defsyms[symidx].explanation);
#else
    return defsyms[symidx].explanation;
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

#include "ko_postpos.h"
#include "dlb.h"
#include "mo_reader.h"

/*
 * ------------------------------------------------------------------
 * Message catalog runtime
 *
 * HanNetHack does not link against libintl.  Instead a plain GNU
 * gettext catalog (locale/<lang>/nethack.mo) is shipped inside the
 * nhdat DLB and parsed on the fly by src/mo_reader.c.
 *
 * The public gettext-like helpers (nh_gettext, nh_pgettext) replace
 * the libintl exports; include/i18n.h maps the classic gettext() /
 * pgettext() names onto them with macros so existing call sites
 * need no changes.
 * ------------------------------------------------------------------
 */

/* Cached language info */
static char current_lang[8] = "";
static boolean korean_locale = FALSE;
static mo_catalog *g_catalog = (mo_catalog *) 0;

/*
 * Normalize user/config language values into short codes used by
 * our bundled catalogs ("ko", "en", "ja", "zh").
 *
 * Accepts inputs like:
 *   - "ko", "ko_KR", "ko-KR", "Korean_Korea.utf8"
 *   - "en_US", "English_United States"
 */
static const char *
normalize_language_code(const char *lang, char out[8])
{
    const char *p;
    int n = 0;

    if (!out)
        return "ko";
    out[0] = '\0';

    if (!lang || !*lang)
        lang = "ko";

    /* Handle common language names first. */
    if (!strncmpi(lang, "korean", 6))
        lang = "ko";
    else if (!strncmpi(lang, "english", 7))
        lang = "en";
    else if (!strncmpi(lang, "japanese", 8))
        lang = "ja";
    else if (!strncmpi(lang, "chinese", 7))
        lang = "zh";

    /* Pull primary subtag until separator (ko_KR -> ko, ko-KR -> ko). */
    for (p = lang; *p && n < 7; ++p) {
        char c = *p;
        if (c == '_' || c == '-' || c == '.' || c == '@' || c == ' ')
            break;
        if (c >= 'A' && c <= 'Z')
            c = (char) (c - 'A' + 'a');
        out[n++] = c;
    }
    out[n] = '\0';

    /* Defensive fallback to Korean default for empty/garbage input. */
    if (!out[0])
        Strcpy(out, "ko");
    return out;
}

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
 * Attempt to load locale/<lang>/nethack.mo through the DLB layer.
 * On success installs the catalog as g_catalog and returns TRUE.
 * Any previously loaded catalog is freed regardless of outcome.
 */
static boolean
load_catalog_for_lang(const char *lang)
{
    char path[BUFSZ];
    char normalized[8];
    uint8_t *buf;
    size_t len = 0;
    mo_catalog *cat;

    if (g_catalog) {
        mo_free(g_catalog);
        g_catalog = (mo_catalog *) 0;
    }
    lang = normalize_language_code(lang, normalized);
    if (!lang || !*lang || strcmp(lang, "en") == 0)
        return FALSE;

    Snprintf(path, sizeof path, "locale/%s/nethack.mo", lang);
    buf = slurp_dlb_file(path, &len);
    if (!buf)
        return FALSE;

    cat = mo_load(buf, len);
    if (!cat) {
        /* mo_load() frees the buffer on failure. */
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
 *   2. Load the .mo catalog through the DLB so nh_gettext & friends
 *      start returning translated strings.
 */
void
set_language(const char *lang)
{
    char normalized[8];
    const char *locale_name;
    char *loc_result;

    /* Keep language handling robust against full locale/name inputs. */
    lang = normalize_language_code(lang, normalized);

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

    /* Load the message catalog via DLB.  Failure is not fatal -
     * nh_gettext will simply echo the English msgid back. */
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
 * Process Korean postpositions in a translated string.
 *
 * Performs sprintf-style formatting into a temporary buffer and
 * then delegates the actual {X/Y} replacement to the single
 * implementation in src/ko_postpos.c.  Assumes `buf` is a BUFSZ-
 * sized char array (matches every call site).
 *
 * Usage:
 *   char buf[BUFSZ];
 *   process_korean_postpositions(buf, "%s{을/를} 때렸다.", mon_nam(mtmp));
 */
char *
process_korean_postpositions(char *buf, const char *format, ...)
{
    va_list args;
    char temp[BUFSZ * 2];

    if (!buf || !format)
        return buf;

    va_start(args, format);
    nh_vsnprintf(temp, sizeof temp, format, args);
    va_end(args);

    if (!korean_locale) {
        strncpy(buf, temp, BUFSZ - 1);
        buf[BUFSZ - 1] = '\0';
        return buf;
    }

    return ko_process_string(buf, BUFSZ, temp);
}

/*
 * Apply Korean postpositions to an already-formatted string.
 *
 * Convenience wrapper for callers that already have the fully
 * formatted string on hand and just need the {X/Y} markers
 * resolved.  Result is written back into `str`, which is assumed
 * to be a BUFSZ-sized buffer.
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

    strncpy(temp, str, BUFSZ - 1);
    temp[BUFSZ - 1] = '\0';

    return ko_process_string(str, BUFSZ, temp);
}

#endif /* ENABLE_NLS */
