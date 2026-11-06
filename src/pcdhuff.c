/*
 *  pcdhuff.c
 *  Quicklook-PCD
 *
 * Copyright (C) 2026 Julie Porter
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * See pcdhuff.h for the layout.
 */
#include "pcdhuff.h"

#include <stdlib.h>
#include <string.h>

#define SECTOR 2048

void PCDFreePlanes(PCDPlanes *p)
{
    free(p->y); free(p->c1); free(p->c2);
    p->y = p->c1 = p->c2 = NULL;
    p->w = p->h = 0;
}

static int alloc_planes(PCDPlanes *p, int w, int h)
{
    p->w = w; p->h = h;
    p->y = malloc((size_t) w * h);
    p->c1 = malloc((size_t)(w / 2) * (h / 2));
    p->c2 = malloc((size_t)(w / 2) * (h / 2));
    if (!p->y || !p->c1 || !p->c2) { PCDFreePlanes(p); return 0; }
    return 1;
}

/* Photo CD 2x: in (w x h) -> out (2w x 2h) */
static void upsample(const unsigned char *in, int w, int h, unsigned char *out)
{
    const int W = 2 * w;
    int x, y;
    for (y = 0; y < h; y++) {
        const unsigned char *p = in + (size_t) y * w;
        unsigned char *q = out + (size_t)(2 * y) * W;
        for (x = 0; x < w; x++) {
            q[2 * x] = p[x];
            q[2 * x + 1] = x + 1 < w ? (unsigned char)((p[x] + p[x + 1] + 1) >> 1) : p[x];
        }
    }
    for (y = 0; y < h; y++) {
        unsigned char *q = out + (size_t)(2 * y + 1) * W;
        const unsigned char *a = in + (size_t) y * w, *b;
        if (y + 1 >= h) { memcpy(q, out + (size_t)(2 * y) * W, (size_t) W); continue; }
        b = a + w;
        for (x = 0; x < w; x++) {
            q[2 * x] = (unsigned char)((a[x] + b[x] + 1) >> 1);
            q[2 * x + 1] = x + 1 < w ? (unsigned char)((a[x] + a[x + 1] + b[x] + b[x + 1] + 2) >> 2)
                                     : (unsigned char)((a[x] + b[x] + 1) >> 1);
        }
    }
}

static int upsample_planes(const PCDPlanes *in, PCDPlanes *out)
{
    if (!alloc_planes(out, 2 * in->w, 2 * in->h)) return 0;
    upsample(in->y, in->w, in->h, out->y);
    upsample(in->c1, in->w / 2, in->h / 2, out->c1);
    upsample(in->c2, in->w / 2, in->h / 2, out->c2);
    return 1;
}

/* ---------------------------------------------------------------------- */

typedef struct {
    short look[65536];          /* a 16-bit prefix -> entry, -1 none */
    unsigned char length[256];
    signed char delta[256];
} Table;

/* `count` tables at byte `off`; 0 on a malformed table */
static int read_tables(const unsigned char *pac, size_t n, size_t off, int count, Table *t)
{
    int k, i;
    size_t p = off;
    for (k = 0; k < count; k++) {
        int entries;
        if (p >= n) return 0;
        entries = pac[p++] + 1;
        for (i = 0; i < 65536; i++) t[k].look[i] = -1;
        for (i = 0; i < entries; i++, p += 4) {
            unsigned len, code, span, base, j;
            if (p + 4 > n) return 0;
            len = pac[p] + 1u;
            code = (unsigned) pac[p + 1] << 8 | pac[p + 2];
            if (len > 16) return 0;
            t[k].length[i] = (unsigned char) len;
            t[k].delta[i] = (signed char) pac[p + 3];
            span = 1u << (16 - len);
            base = code & ~(span - 1) & 0xFFFF;
            for (j = 0; j < span; j++)
                if (t[k].look[base + j] < 0) t[k].look[base + j] = (short) i;
        }
    }
    return 1;
}

/* MSB-first bits: a peek of up to 24 */
typedef struct { const unsigned char *d; size_t n, bit; } Bits;

static unsigned peek(const Bits *b, int nbits)
{
    const size_t o = b->bit >> 3;
    unsigned w = 0;
    int i;
    for (i = 0; i < 4; i++) w = w << 8 | (o + i < b->n ? b->d[o + i] : 0);
    return (w << (b->bit & 7)) >> (32 - nbits);
}

/* Add the deltas of the rows at byte `off` to `pl`.  1 on reaching the
 * terminator (or the end of the file after some rows), 0 on a bad code. */
static int decode_rows(const unsigned char *pac, size_t n, size_t off, const Table *t, int ntab,
                       PCDPlanes *pl)
{
    Bits b;
    int rows = 0;
    b.d = pac; b.n = n; b.bit = off * 8;
    for (;;) {
        unsigned hdr;
        int plane, row, count, tab, i;
        unsigned char *q;
        while ((b.bit >> 3) + 3 < n && peek(&b, 24) != 0xFFFFFEu) b.bit++;
        if ((b.bit >> 3) + 5 >= n) return rows > 0;
        b.bit += 24;
        hdr = peek(&b, 16);
        b.bit += 16;
        plane = (int)(hdr >> 14);
        row = (int)((hdr >> 1) & 0x1FFF);
        if (row >= pl->h) return 1;
        if (plane == 0) { q = pl->y + (size_t) row * pl->w; count = pl->w; tab = 0; }
        else if ((plane == 2 || plane == 3) && ntab == 3) {
            q = (plane == 2 ? pl->c1 : pl->c2) + (size_t)(row / 2) * (pl->w / 2);
            count = pl->w / 2;
            tab = plane - 1;
        } else return 0;
        for (i = 0; i < count; i++) {
            const int e = t[tab].look[peek(&b, 16)];
            int v;
            if (e < 0) return 0;
            v = q[i] + t[tab].delta[e];
            q[i] = (unsigned char)(v < 0 ? 0 : v > 255 ? 255 : v);
            b.bit += t[tab].length[e];
        }
        rows++;
    }
}

/* ---------------------------------------------------------------------- */

int PCDDecode(const unsigned char *pac, size_t n, int want, PCDPlanes *out)
{
    PCDPlanes base = { 0 }, p4 = { 0 }, p16 = { 0 };
    const unsigned char *p;
    Table *t;
    size_t ipe;
    int y;

    memset(out, 0, sizeof *out);
    if (n < 0xC0000 || !alloc_planes(&base, 768, 512)) return 0;
    p = pac + 96 * SECTOR;                              /* Y Y C1 C2, row pairs */
    for (y = 0; y < 512; y += 2) {
        memcpy(base.y + (size_t) y * 768, p, 768); p += 768;
        memcpy(base.y + (size_t)(y + 1) * 768, p, 768); p += 768;
        memcpy(base.c1 + (size_t)(y / 2) * 384, p, 384); p += 384;
        memcpy(base.c2 + (size_t)(y / 2) * 384, p, 384); p += 384;
    }
    if (want < 4 || n < 390 * SECTOR) { *out = base; return 3; }

    t = malloc(3 * sizeof *t);
    if (!t) { *out = base; return 3; }
    /* 4Base: luma only, over Base twice the size */
    if (!read_tables(pac, n, 388 * SECTOR, 1, t) || !upsample_planes(&base, &p4)
        || !decode_rows(pac, n, 389 * SECTOR, t, 1, &p4)) {
        PCDFreePlanes(&p4);
        free(t);
        *out = base;
        return 3;
    }
    PCDFreePlanes(&base);
    ipe = (size_t) pac[0x0E03] << 8 | pac[0x0E04];
    if (want < 5 || ipe < 390 || n < (ipe + 15) * SECTOR) { free(t); *out = p4; return 4; }

    /* 16Base: luma and chroma, over 4Base twice the size */
    if (!read_tables(pac, n, (ipe + 12) * SECTOR, 3, t) || !upsample_planes(&p4, &p16)
        || !decode_rows(pac, n, (ipe + 14) * SECTOR, t, 3, &p16)) {
        PCDFreePlanes(&p16);
        free(t);
        *out = p4;
        return 4;
    }
    free(t);
    PCDFreePlanes(&p4);
    *out = p16;
    return 5;
}

/* ---------------------------------------------------------------------- */

#define CHOP(x) ((x) < 0 ? 0 : ((x) > 255 ? 255 : (x)))

void PCDToRGB(const PCDPlanes *p, unsigned char *rgb, size_t stride)
{
    int x, y;
    for (y = 0; y < p->h; y++) {
        const unsigned char *yr = p->y + (size_t) y * p->w;
        const unsigned char *c1 = p->c1 + (size_t)(y / 2) * (p->w / 2);
        const unsigned char *c2 = p->c2 + (size_t)(y / 2) * (p->w / 2);
        unsigned char *o = rgb + (size_t) y * stride;
        for (x = 0; x < p->w; x++) {
            const double U = 2.2179 * (c1[x / 2] - 156), V = 1.8215 * (c2[x / 2] - 137);
            const double Y = yr[x] * 1.3584;
            const double tR = (Y + V - 16) * (255.0 / 330.0);
            const double tG = (Y - 0.194 * U - 0.509 * V - 16) * (255.0 / 330.0);
            const double tB = (Y + U - 16) * (255.0 / 330.0);
            const int r = (int) tR, g = (int) tG, b = (int) tB;
            o[3 * x] = (unsigned char) CHOP(r);
            o[3 * x + 1] = (unsigned char) CHOP(g);
            o[3 * x + 2] = (unsigned char) CHOP(b);
        }
    }
}
