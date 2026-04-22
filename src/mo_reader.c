/* NetHack 3.7  mo_reader.c  */
/* Copyright (c) HanNetHack Project, 2026. */
/* NetHack may be freely redistributed.  See license for details. */

/*
 * In-memory reader for GNU gettext .mo catalogs, with a thin XOR
 * wrapper (.mox) for the shipped catalog bytes.  See mo_reader.h
 * and mox_format.h for the external contract.
 *
 * Implementation notes:
 *   - The raw catalog buffer is retained after parsing so we can
 *     return pointers into it for translations.  No string copies
 *     are made for the strings themselves.
 *   - Lookups go through an FNV-1a keyed open-addressing hash
 *     table sized to 2x the entry count, rounded up to a power of
 *     two.  Worst case linear probe stays short.
 *   - Endian handling: real-world .mo files are almost always
 *     little-endian, but the format permits either; we honor the
 *     magic value to decide.
 *   - This module deliberately avoids NetHack headers so it can
 *     be unit-tested standalone if desired.
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "mo_reader.h"
#include "mox_format.h"

/* Standard GNU gettext .mo magic, little-endian on disk. */
#define MO_MAGIC_LE 0x950412deU
#define MO_MAGIC_BE 0xde120495U

struct mo_entry {
    const char *key;   /* points into catalog->raw */
    const char *value; /* points into catalog->raw */
    uint32_t   keylen;
};

struct mo_catalog {
    uint8_t          *raw;          /* owned */
    size_t            raw_len;
    struct mo_entry  *entries;
    size_t            n_entries;
    uint32_t         *htable;       /* index into entries, or HASH_EMPTY */
    size_t            htable_mask;  /* htable_size - 1, size is power of 2 */
};

#define HASH_EMPTY 0xFFFFFFFFu

/* -------- helpers -------- */

static uint32_t
read_u32(const uint8_t *p, int big_endian)
{
    if (big_endian) {
        return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16)
             | ((uint32_t) p[2] << 8)  |  (uint32_t) p[3];
    }
    return  (uint32_t) p[0]
         | ((uint32_t) p[1] << 8)
         | ((uint32_t) p[2] << 16)
         | ((uint32_t) p[3] << 24);
}

static uint32_t
fnv1a(const char *s, size_t len)
{
    uint32_t h = 0x811c9dc5u;
    size_t i;

    for (i = 0; i < len; i++) {
        h ^= (uint8_t) s[i];
        h *= 0x01000193u;
    }
    return h;
}

static size_t
next_pow2(size_t n)
{
    size_t p = 1;

    while (p < n)
        p <<= 1;
    return p;
}

/* -------- hash table construction -------- */

static int
catalog_build_hash(mo_catalog *cat)
{
    size_t size = next_pow2(cat->n_entries * 2 + 1);
    size_t i;

    if (size < 8)
        size = 8;

    cat->htable = (uint32_t *) malloc(size * sizeof(uint32_t));
    if (!cat->htable)
        return 0;
    for (i = 0; i < size; i++)
        cat->htable[i] = HASH_EMPTY;
    cat->htable_mask = size - 1;

    for (i = 0; i < cat->n_entries; i++) {
        uint32_t h = fnv1a(cat->entries[i].key, cat->entries[i].keylen);
        size_t slot = h & cat->htable_mask;

        /* Linear probe until empty slot. */
        while (cat->htable[slot] != HASH_EMPTY)
            slot = (slot + 1) & cat->htable_mask;
        cat->htable[slot] = (uint32_t) i;
    }
    return 1;
}

/* -------- MO parsing -------- */

/*
 * Parse the raw .mo bytes.  On success fills in cat->entries and
 * cat->n_entries.  Returns 1 on success, 0 on malformed input.
 */
static int
parse_mo(mo_catalog *cat)
{
    const uint8_t *buf = cat->raw;
    size_t len = cat->raw_len;
    uint32_t magic;
    int be;
    uint32_t nstrings, orig_ofs, trans_ofs;
    uint32_t i;

    if (len < 28)
        return 0;

    magic = read_u32(buf, 0);
    if (magic == MO_MAGIC_LE) {
        be = 0;
    } else if (magic == MO_MAGIC_BE) {
        be = 1;
    } else {
        return 0;
    }

    /* buf[4..7] is revision; ignored. */
    nstrings  = read_u32(buf + 8,  be);
    orig_ofs  = read_u32(buf + 12, be);
    trans_ofs = read_u32(buf + 16, be);

    /* Sanity: each entry is 8 bytes (length + offset). */
    if (nstrings == 0)
        return 1; /* Empty but valid catalog. */
    if ((uint64_t) orig_ofs  + (uint64_t) nstrings * 8 > len)
        return 0;
    if ((uint64_t) trans_ofs + (uint64_t) nstrings * 8 > len)
        return 0;

    cat->entries = (struct mo_entry *)
        calloc(nstrings, sizeof(struct mo_entry));
    if (!cat->entries)
        return 0;
    cat->n_entries = nstrings;

    for (i = 0; i < nstrings; i++) {
        uint32_t klen = read_u32(buf + orig_ofs  + i * 8,     be);
        uint32_t kofs = read_u32(buf + orig_ofs  + i * 8 + 4, be);
        uint32_t vlen = read_u32(buf + trans_ofs + i * 8,     be);
        uint32_t vofs = read_u32(buf + trans_ofs + i * 8 + 4, be);

        /* String bounds check; every stored string has a trailing NUL. */
        if ((uint64_t) kofs + klen + 1 > len)
            return 0;
        if ((uint64_t) vofs + vlen + 1 > len)
            return 0;
        if (buf[kofs + klen] != 0 || buf[vofs + vlen] != 0)
            return 0;

        cat->entries[i].key    = (const char *) (buf + kofs);
        cat->entries[i].keylen = klen;
        cat->entries[i].value  = (const char *) (buf + vofs);
    }

    return 1;
}

/* -------- public API -------- */

mo_catalog *
mo_load(uint8_t *mo_data, size_t len)
{
    mo_catalog *cat;

    if (!mo_data) {
        return NULL;
    }

    cat = (mo_catalog *) calloc(1, sizeof(*cat));
    if (!cat) {
        free(mo_data);
        return NULL;
    }
    cat->raw = mo_data;
    cat->raw_len = len;

    if (!parse_mo(cat) || !catalog_build_hash(cat)) {
        mo_free(cat);
        return NULL;
    }
    return cat;
}

mo_catalog *
mox_load(uint8_t *mox_data, size_t len)
{
    uint32_t version, orig_size;
    uint8_t nonce[MOX_NONCE_SIZE];
    uint8_t *mo_bytes;

    if (!mox_data)
        return NULL;

    if (len < MOX_HEADER_SIZE
        || memcmp(mox_data, MOX_MAGIC, MOX_MAGIC_LEN) != 0) {
        free(mox_data);
        return NULL;
    }

    version = read_u32(mox_data + 4, 0);
    if (version != MOX_VERSION) {
        free(mox_data);
        return NULL;
    }

    orig_size = read_u32(mox_data + 8, 0);
    if (orig_size != len - MOX_HEADER_SIZE) {
        free(mox_data);
        return NULL;
    }

    memcpy(nonce, mox_data + 12, MOX_NONCE_SIZE);

    /*
     * Decode in place and then shift the decoded payload to the
     * start of the buffer so the catalog owns a clean .mo image
     * and downstream bounds checks can use offsets directly.
     */
    mox_xor_stream(mox_data + MOX_HEADER_SIZE, orig_size, nonce);

    mo_bytes = (uint8_t *) malloc(orig_size ? orig_size : 1);
    if (!mo_bytes) {
        free(mox_data);
        return NULL;
    }
    memcpy(mo_bytes, mox_data + MOX_HEADER_SIZE, orig_size);
    free(mox_data);

    return mo_load(mo_bytes, (size_t) orig_size);
}

const char *
mo_lookup(const mo_catalog *cat, const char *msgid)
{
    size_t slot, start;
    size_t msgid_len;

    if (!cat || !msgid || !cat->htable || cat->n_entries == 0)
        return NULL;

    msgid_len = strlen(msgid);
    slot = fnv1a(msgid, msgid_len) & cat->htable_mask;
    start = slot;

    do {
        uint32_t idx = cat->htable[slot];

        if (idx == HASH_EMPTY)
            return NULL;
        if (cat->entries[idx].keylen == msgid_len
            && memcmp(cat->entries[idx].key, msgid, msgid_len) == 0) {
            const char *v = cat->entries[idx].value;
            /*
             * The empty msgid at the start of every catalog carries
             * header metadata (Content-Type, Plural-Forms, ...).  A
             * caller looking up "" almost certainly does not want
             * that; but callers looking up real strings should get
             * them even if their translation happens to be empty.
             * We just return the value verbatim.
             */
            return v;
        }
        slot = (slot + 1) & cat->htable_mask;
    } while (slot != start);

    return NULL;
}

const char *
mo_lookup_ctx(const mo_catalog *cat, const char *ctx, const char *msgid)
{
    /*
     * gettext encodes context-qualified messages with a literal
     * EOT (0x04) joiner: "ctx\x04msgid".  We build the key on the
     * stack (large enough for any reasonable NetHack message) and
     * fall back to a heap buffer only if it doesn't fit.
     */
    char small[512];
    char *key = small;
    size_t ctx_len, msgid_len, total;
    const char *result;

    if (!cat || !msgid)
        return NULL;
    if (!ctx || !*ctx)
        return mo_lookup(cat, msgid);

    ctx_len   = strlen(ctx);
    msgid_len = strlen(msgid);
    total     = ctx_len + 1 + msgid_len + 1;

    if (total > sizeof small) {
        key = (char *) malloc(total);
        if (!key)
            return NULL;
    }

    memcpy(key, ctx, ctx_len);
    key[ctx_len] = '\x04';
    memcpy(key + ctx_len + 1, msgid, msgid_len);
    key[total - 1] = '\0';

    result = mo_lookup(cat, key);

    if (key != small)
        free(key);
    return result;
}

size_t
mo_count(const mo_catalog *cat)
{
    return cat ? cat->n_entries : 0;
}

void
mo_free(mo_catalog *cat)
{
    if (!cat)
        return;
    free(cat->htable);
    free(cat->entries);
    free(cat->raw);
    free(cat);
}

/*mo_reader.c*/
