/* NetHack 3.7  mox_format.h  */
/* Copyright (c) HanNetHack Project, 2026. */
/* NetHack may be freely redistributed.  See license for details. */

/*
 * Shared constants for the HanNetHack .mox message catalog format.
 *
 * A .mox file is a GNU gettext .mo catalog whose payload has been
 * XOR-stream encoded with an xorshift64 keystream derived from a
 * per-file nonce combined with a compile-time seed constant.  This
 * hides plain-text translations from casual inspection (strings(1),
 * msgunfmt(1), grep(1)) while keeping runtime decoding cheap.
 *
 * File layout (all little-endian):
 *
 *   offset  size  field
 *   ------  ----  ----------------------------------------------
 *     0     4     magic "MOX1"                (MOX_MAGIC)
 *     4     4     format version              (MOX_VERSION)
 *     8     4     size of decoded payload     (original .mo size)
 *    12     8     per-file nonce
 *    20     N     XOR-encoded payload (== .mo bytes)
 *
 * This is obfuscation, not cryptography: anyone with the source or
 * a disassembler can recover the seed and decode the catalog.  The
 * goal is only to raise the bar above "open in a text editor".
 */

#ifndef MOX_FORMAT_H
#define MOX_FORMAT_H

#include <stdint.h>

#define MOX_MAGIC       "MOX1"
#define MOX_MAGIC_LEN   4
#define MOX_VERSION     1u
#define MOX_HEADER_SIZE 20u
#define MOX_NONCE_SIZE  8u

/*
 * Compile-time seed constant.  Mixed with the per-file nonce to form
 * the xorshift64 keystream seed.  Change this and all previously
 * built .mox catalogs will stop decoding, so treat as stable.
 *
 * Not a secret - it lives in the public source tree - but distinct
 * enough to ensure the encoded bytes look random to casual tools.
 */
#define MOX_SEED_CONSTANT UINT64_C(0xA17C9E3B4D5F2B89)

/*
 * xorshift64 step.  Requires state != 0.  Kept in the header so the
 * reader and the encoder are guaranteed to use the exact same stream.
 */
static inline uint64_t
mox_xorshift64(uint64_t *state)
{
    uint64_t x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    return x;
}

/*
 * Derive the keystream seed from the compile-time constant and the
 * per-file 8-byte nonce.  Never returns 0 (xorshift64 would stall).
 */
static inline uint64_t
mox_derive_seed(const uint8_t nonce[MOX_NONCE_SIZE])
{
    uint64_t seed = MOX_SEED_CONSTANT;
    int i;

    for (i = 0; i < (int) MOX_NONCE_SIZE; i++)
        seed ^= ((uint64_t) nonce[i]) << (i * 8);

    if (seed == 0)
        seed = UINT64_C(0x1);
    return seed;
}

/*
 * Decode (or encode - XOR is symmetric) `len` bytes of `buf` in place
 * using the keystream derived from `nonce`.
 */
static inline void
mox_xor_stream(uint8_t *buf, size_t len, const uint8_t nonce[MOX_NONCE_SIZE])
{
    uint64_t state = mox_derive_seed(nonce);
    size_t i;
    uint64_t k = 0;
    uint8_t keybytes[8];

    for (i = 0; i < len; i++) {
        if ((i & 7u) == 0u) {
            int j;
            k = mox_xorshift64(&state);
            for (j = 0; j < 8; j++)
                keybytes[j] = (uint8_t) ((k >> (j * 8)) & 0xFFu);
        }
        buf[i] ^= keybytes[i & 7u];
    }
}

#endif /* MOX_FORMAT_H */
