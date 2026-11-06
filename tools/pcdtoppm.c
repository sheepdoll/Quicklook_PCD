/*
 *  pcdtoppm.c
 *  Quicklook-PCD
 *
 * Copyright (C) 2026 Julie Porter
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.  See gpl.txt.
 *
 *   pcdtoppm [-3|-4|-5] [-ycc] IMAGE.PCD out.ppm
 *
 * The extension's reader on the command line: Base (-3), 4Base (-4) or
 * 16Base (-5, the default; the highest present if less).  -ycc writes the
 * planes as stored instead -- a P5 of Y, then C1 and C2 side by side under
 * it -- for checking a decoder byte for byte.
 */
#include "pcdhuff.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    int want = 5, ycc = 0, a = 1, got;
    FILE *f;
    unsigned char *buf, *rgb;
    size_t n, cap = 1 << 22;
    PCDPlanes p;
    static const char *names[] = { "", "", "", "Base", "4Base", "16Base" };

    for (; a < argc && argv[a][0] == '-'; a++) {
        if (!strcmp(argv[a], "-3") || !strcmp(argv[a], "-4") || !strcmp(argv[a], "-5")) want = argv[a][1] - '0';
        else if (!strcmp(argv[a], "-ycc")) ycc = 1;
        else break;
    }
    if (argc - a != 2) { fprintf(stderr, "usage: pcdtoppm [-3|-4|-5] [-ycc] IMAGE.PCD out.ppm\n"); return 2; }
    if (!(f = fopen(argv[a], "rb"))) { perror(argv[a]); return 1; }
    buf = malloc(cap);
    for (n = 0;;) {
        size_t r;
        if (n == cap) buf = realloc(buf, cap *= 2);
        r = fread(buf + n, 1, cap - n, f);
        if (!r) break;
        n += r;
    }
    fclose(f);
    got = PCDDecode(buf, n, want, &p);
    free(buf);
    if (!got) { fprintf(stderr, "%s: not an Image Pac\n", argv[a]); return 1; }
    fprintf(stderr, "%s: %s, %d x %d\n", argv[a], names[got], p.w, p.h);
    if (!(f = fopen(argv[a + 1], "wb"))) { perror(argv[a + 1]); return 1; }
    if (ycc) {
        int y;
        fprintf(f, "P5 %d %d 255\n", p.w, p.h + p.h / 2);
        fwrite(p.y, 1, (size_t) p.w * p.h, f);
        for (y = 0; y < p.h / 2; y++) {
            fwrite(p.c1 + (size_t) y * (p.w / 2), 1, (size_t)(p.w / 2), f);
            fwrite(p.c2 + (size_t) y * (p.w / 2), 1, (size_t)(p.w / 2), f);
        }
    } else {
        rgb = malloc((size_t) p.w * p.h * 3);
        PCDToRGB(&p, rgb, (size_t) p.w * 3);
        fprintf(f, "P6 %d %d 255\n", p.w, p.h);
        fwrite(rgb, 1, (size_t) p.w * p.h * 3, f);
        free(rgb);
    }
    fclose(f);
    PCDFreePlanes(&p);
    return 0;
}
