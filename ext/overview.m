/* ext/overview.m -- an OVERVIEW.PCD as a PDF of contact-sheet pages.
 *
 * The file: `PCD_OPA`, the image count big-endian at byte 10, a rotation code per
 * image from byte 12, and from sector 5 the 192 x 128 images back to back, 18 sectors
 * each.  Checked on PCD1237: 5 + 18 x 70 = its 1265 sectors. */
#import <Cocoa/Cocoa.h>
#import "image.h"
#import "overview.h"

enum { COLS = 5, ROWS = 4, CELL_W = 192, CELL_H = 192, GAP = 8, LABEL = 16 };

BOOL PCDIsOverview(NSString *path)
{
    char sig[7] = { 0 };
    FILE *f = fopen([path fileSystemRepresentation], "r");
    if (!f) return NO;
    const size_t n = fread(sig, 1, sizeof sig, f);
    fclose(f);
    return n == sizeof sig && memcmp(sig, "PCD_OPA", sizeof sig) == 0;
}

CGSize PCDOverviewPageSize(void)
{
    return CGSizeMake(COLS * (CELL_W + GAP) + GAP, ROWS * (CELL_H + GAP + LABEL) + GAP);
}

PDFDocument *PCDOverviewDocument(NSString *path)
{
    unsigned char head[12 + 2048];
    FILE *f = fopen([path fileSystemRepresentation], "r");
    if (!f) return nil;
    const size_t got = fread(head, 1, sizeof head, f);
    fclose(f);
    if (got < sizeof head) return nil;
    const int count = (head[10] << 8) | head[11];
    const CGSize page = PCDOverviewPageSize();
    PDFDocument *doc = [[[PDFDocument alloc] init] autorelease];
    NSDictionary *font = @{ NSFontAttributeName: [NSFont systemFontOfSize:11],
                            NSForegroundColorAttributeName: [NSColor blackColor] };

    for (int i = 0, pageNo = 0; i < count; pageNo++) {
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
            pixelsWide:(NSInteger) page.width pixelsHigh:(NSInteger) page.height bitsPerSample:8
            samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
            bytesPerRow:0 bitsPerPixel:0] autorelease];
        NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:gc];
        CGContextRef ctx = [gc CGContext];
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
        CGContextFillRect(ctx, CGRectMake(0, 0, page.width, page.height));

        for (int k = 0; k < COLS * ROWS && i < count; k++, i++) {
            const CGFloat cx = GAP + (k % COLS) * (CELL_W + GAP) + CELL_W / 2.0;
            const CGFloat top = page.height - GAP - (k / COLS) * (CELL_H + GAP + LABEL);
            const CGFloat cy = top - CELL_H / 2.0;
            pcdReader *reader = [[pcdReader alloc] init];
            [reader setOverviewImage:(unsigned) i];
            CGImageRef image = [reader loadPCD:(CFStringRef) path :1];
            if (image) {
                /* 0..3 quarter turns counter-clockwise [inferred; the frames come out upright] */
                const int turns = head[12 + i] & 3;
                CGContextSaveGState(ctx);
                CGContextTranslateCTM(ctx, cx, cy);
                CGContextRotateCTM(ctx, turns * M_PI_2);
                CGContextDrawImage(ctx, CGRectMake(-96, -64, 192, 128), image);
                CGContextRestoreGState(ctx);
            }
            [reader release];
            [[NSString stringWithFormat:@"%d", i + 1] drawAtPoint:
                NSMakePoint(cx - 96, top - CELL_H - LABEL + 1) withAttributes:font];
        }
        [NSGraphicsContext restoreGraphicsState];
        NSImage *im = [[[NSImage alloc] initWithSize:NSSizeFromCGSize(page)] autorelease];
        [im addRepresentation:rep];
        PDFPage *p = [[[PDFPage alloc] initWithImage:im] autorelease];
        if (p) [doc insertPage:p atIndex:pageNo];
    }
    return doc;
}
