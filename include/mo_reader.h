/* NetHack 3.7  mo_reader.h  */
/* Copyright (c) HanNetHack Project, 2026. */
/* NetHack may be freely redistributed.  See license for details. */

/*
 * In-memory GNU gettext message catalog reader.
 *
 * HanNetHack replaces the runtime libintl dependency with this tiny
 * loader so that .mo catalogs can be bundled inside the nhdat DLB
 * and parsed directly in-process.
 *
 * Usage:
 *   mo_catalog *cat = mo_load(buf, len);   // takes ownership of buf
 *   const char *tr  = mo_lookup(cat, "You die...");
 *   const char *ctx = mo_lookup_ctx(cat, "spell", "magic missile");
 *   mo_free(cat);
 *
 * Thread safety: read-only lookups are safe once the catalog has
 * been loaded.  Loading itself is not thread-safe.
 */

#ifndef MO_READER_H
#define MO_READER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct mo_catalog mo_catalog;

/*
 * Parse a .mo buffer.  Ownership of the buffer transfers to the
 * returned catalog, which will free it in mo_free().
 *
 * Returns NULL on any error (bad magic, truncated file, malformed
 * catalog, allocation failure).  On failure the buffer is freed as
 * a courtesy so callers can treat mo_load() like a take-ownership
 * constructor regardless of outcome.
 */
mo_catalog *mo_load(uint8_t *mo_data, size_t len);

/*
 * Look up a plain msgid.  Returns the translation on hit, NULL on
 * miss.  Callers usually want to fall back to msgid on miss.
 */
const char *mo_lookup(const mo_catalog *cat, const char *msgid);

/*
 * Context-aware lookup (pgettext).  Equivalent to looking up
 * "ctx\x04msgid".
 */
const char *mo_lookup_ctx(const mo_catalog *cat,
                          const char *ctx, const char *msgid);

/*
 * Number of parsed entries.  Mostly useful for diagnostics.
 */
size_t mo_count(const mo_catalog *cat);

/*
 * Free the catalog and its owned buffer.  Safe to call with NULL.
 */
void mo_free(mo_catalog *cat);

#ifdef __cplusplus
}
#endif

#endif /* MO_READER_H */
