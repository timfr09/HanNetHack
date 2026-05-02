/* NetHack 3.7  test_mo_reader.c  */
/* Copyright (c) HanNetHack Project, 2026. */
/* NetHack may be freely redistributed.  See license for details. */

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS 1
#endif

/*
 * Standalone smoke test for mo_reader.
 *
 *   test_mo_reader <catalog.mo>
 *
 * Exits 0 on success, non-zero on any parsing or lookup failure.
 * Intended for CI / local dev; not shipped.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "mo_reader.h"

static uint8_t *
slurp(const char *path, size_t *out_len)
{
    FILE *f = fopen(path, "rb");
    uint8_t *buf;
    long sz;

    if (!f) {
        fprintf(stderr, "cannot open %s\n", path);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    sz = ftell(f);
    rewind(f);
    buf = (uint8_t *) malloc((size_t) sz ? (size_t) sz : 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    if (sz > 0 && fread(buf, 1, (size_t) sz, f) != (size_t) sz) {
        free(buf);
        fclose(f);
        return NULL;
    }
    fclose(f);
    *out_len = (size_t) sz;
    return buf;
}

int
main(int argc, char **argv)
{
    const char *path;
    uint8_t *buf;
    size_t len;
    mo_catalog *cat;
    const char *hdr;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <catalog.mo>\n", argv[0]);
        return 2;
    }
    path = argv[1];

    buf = slurp(path, &len);
    if (!buf)
        return 1;

    cat = mo_load(buf, len);
    if (!cat) {
        fprintf(stderr, "FAIL: catalog did not parse\n");
        return 1;
    }

    printf("entries: %zu\n", mo_count(cat));

    /*
     * The empty msgid holds the catalog header (Content-Type,
     * Plural-Forms, etc.).  Its presence confirms at minimum a
     * basic parse succeeded.
     */
    hdr = mo_lookup(cat, "");
    if (hdr) {
        const char *nl = strchr(hdr, '\n');
        size_t show = nl ? (size_t) (nl - hdr) : strlen(hdr);
        if (show > 120) show = 120;
        printf("header[0]: %.*s\n", (int) show, hdr);
    } else {
        printf("header: (none)\n");
    }

    /*
     * Spot-check a handful of stable NetHack messages.  Any hit
     * means hash-table lookup works.  Misses are not fatal - the
     * string may have been rephrased - but we expect at least one
     * to succeed in a real catalog.
     */
    {
        static const char *const probes[] = {
            "You die...",
            "Hello stranger, who are you?",
            "Welcome to NetHack!",
            "Yes",
            "No",
            "gold piece",
            NULL
        };
        int hits = 0;
        int i;

        for (i = 0; probes[i]; i++) {
            const char *tr = mo_lookup(cat, probes[i]);
            if (tr && *tr && strcmp(tr, probes[i]) != 0) {
                printf("lookup  \"%s\" -> \"%s\"\n", probes[i], tr);
                hits++;
            }
        }
        if (mo_count(cat) > 10 && hits == 0) {
            fprintf(stderr, "FAIL: no probe strings hit in non-empty catalog\n");
            mo_free(cat);
            return 1;
        }
    }

    mo_free(cat);
    return 0;
}
