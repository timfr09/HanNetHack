/* NetHack 3.7  encode_mo.c  */
/* Copyright (c) HanNetHack Project, 2026. */
/* NetHack may be freely redistributed.  See license for details. */

/* MSVC's "safer" fopen_s buys us nothing here - standalone tool. */
#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS 1
#endif

/*
 * Build-time utility: convert a GNU gettext .mo catalog to the
 * HanNetHack .mox format (XOR-stream obfuscated) for shipping.
 *
 *   encode_mo <input.mo> <output.mox>
 *
 * The .mox format is documented in include/mox_format.h.  This
 * tool is intentionally standalone (only libc) so it can run in
 * any NetHack build environment.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#endif

#include "mox_format.h"

static void
die(const char *msg, const char *arg)
{
    if (arg)
        fprintf(stderr, "encode_mo: %s: %s\n", msg, arg);
    else
        fprintf(stderr, "encode_mo: %s\n", msg);
    exit(1);
}

static void
fill_nonce(uint8_t out[MOX_NONCE_SIZE])
{
    /*
     * Nonce quality is only relevant for making encoded bytes look
     * random to casual tools; rand() with a time+pid seed is plenty
     * for that.  Every rebuild produces a fresh nonce which also
     * means the on-disk .mox differs even when the source .mo is
     * byte-identical - nice for reproducible-build hardening
     * detection, less nice for strict bit-for-bit reproducibility.
     */
    unsigned int seed = (unsigned int) time(NULL);
    int i;

#ifdef _WIN32
    seed ^= (unsigned int) _getpid();
#else
    seed ^= (unsigned int) getpid();
#endif
    srand(seed);
    for (i = 0; i < (int) MOX_NONCE_SIZE; i++)
        out[i] = (uint8_t) (rand() & 0xFF);
}

static uint8_t *
slurp(const char *path, size_t *out_len)
{
    FILE *f = fopen(path, "rb");
    uint8_t *buf;
    long sz;

    if (!f)
        die("cannot open input", path);

    if (fseek(f, 0, SEEK_END) != 0)
        die("seek failed on input", path);
    sz = ftell(f);
    if (sz < 0)
        die("ftell failed on input", path);
    rewind(f);

    buf = (uint8_t *) malloc((size_t) sz ? (size_t) sz : 1);
    if (!buf)
        die("out of memory reading input", path);
    if (sz > 0 && fread(buf, 1, (size_t) sz, f) != (size_t) sz)
        die("short read on input", path);
    fclose(f);

    *out_len = (size_t) sz;
    return buf;
}

static void
write_u32_le(FILE *f, uint32_t v)
{
    uint8_t b[4];

    b[0] = (uint8_t) (v       & 0xFF);
    b[1] = (uint8_t) (v >> 8  & 0xFF);
    b[2] = (uint8_t) (v >> 16 & 0xFF);
    b[3] = (uint8_t) (v >> 24 & 0xFF);
    if (fwrite(b, 1, 4, f) != 4)
        die("write error", NULL);
}

int
main(int argc, char **argv)
{
    const char *in_path;
    const char *out_path;
    uint8_t *payload;
    size_t payload_len;
    uint8_t nonce[MOX_NONCE_SIZE];
    FILE *out;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s <input.mo> <output.mox>\n", argv[0]);
        return 2;
    }
    in_path  = argv[1];
    out_path = argv[2];

    payload = slurp(in_path, &payload_len);
    if (payload_len > UINT32_MAX)
        die("input .mo too large", in_path);

    fill_nonce(nonce);
    mox_xor_stream(payload, payload_len, nonce);

    out = fopen(out_path, "wb");
    if (!out)
        die("cannot open output", out_path);

    if (fwrite(MOX_MAGIC, 1, MOX_MAGIC_LEN, out) != MOX_MAGIC_LEN)
        die("write error", out_path);
    write_u32_le(out, MOX_VERSION);
    write_u32_le(out, (uint32_t) payload_len);
    if (fwrite(nonce, 1, MOX_NONCE_SIZE, out) != MOX_NONCE_SIZE)
        die("write error", out_path);
    if (payload_len > 0
        && fwrite(payload, 1, payload_len, out) != payload_len)
        die("write error", out_path);

    if (fclose(out) != 0)
        die("close failed", out_path);
    free(payload);

    return 0;
}
