/*
 *  pcdhuff.h
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
 * The Image Pac above Base: 4Base (1536 x 1024) and 16Base (3072 x 2048),
 * Huffman-coded residuals over the 2x upsampled resolution below.  Plain C,
 * no Cocoa: src/image.m calls it, and so does tools/pcdtoppm.c.
 *
 * Read off five Image Pacs written by FilmScanner 2000s in the field, and
 * checked by rebuilding four of them byte for byte (k4050Diagnostics
 * scnCalibWx, src/pcd/PcdHuffman.cpp, 2026-11-05):
 *
 *   sector  96        Base: row groups Y Y C1 C2 (768 x 512, chroma 384 x 256)
 *   sector 388        4Base table: a count byte (n - 1), then n entries of
 *                     (length - 1, code left-aligned in 16 bits, signed delta)
 *   sector 389        4Base rows, luma only (its chroma is Base's, upsampled)
 *   IPI 0x0E03 (BE)   the IPE: the sector after 4Base's last
 *   IPE + 12          16Base tables: Y, C1, C2
 *   IPE + 14          16Base rows: every Y row, then C1 / C2 by even row
 *
 * A row: the sync FF FF FE, a 16-bit header (plane 2 bits: 0 Y, 2 C1, 3 C2;
 * row 13 bits, in luma rows; 1 spare), then one code per pixel, packed with
 * no alignment.  A row number at or past the height ends the section.  The
 * upsample: even samples copied, odd ones the rounded mean of their
 * neighbours, the last column / row repeated.
 */
#ifndef PCDHUFF_H
#define PCDHUFF_H

#include <stddef.h>

/* one resolution in PhotoYCC 4:2:0: y is w x h, c1 / c2 (w/2) x (h/2) */
typedef struct {
    int w, h;
    unsigned char *y, *c1, *c2;
} PCDPlanes;

void PCDFreePlanes(PCDPlanes *p);

/* Base and up out of a whole Pac in memory.  `want`: 3 Base, 4 4Base,
 * 5 16Base.  Fills `out` with the highest resolution present up to `want`
 * and returns it (3, 4 or 5), or 0 if the file has no Base. */
int PCDDecode(const unsigned char *pac, size_t n, int want, PCDPlanes *out);

/* PhotoYCC -> 8-bit RGB, 3 bytes a pixel, rows of `stride` bytes: image.m's
 * PSCS arithmetic (luma x 1.3584, C1 2.2179 about 156, C2 1.8215 about 137,
 * then (v - 16) x 255 / 330), a pixel at a time instead of through full-size
 * double planes -- 16Base would have needed ~190 MB */
void PCDToRGB(const PCDPlanes *p, unsigned char *rgb, size_t stride);

#endif
