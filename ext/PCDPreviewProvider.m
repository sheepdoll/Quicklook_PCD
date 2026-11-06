/* ext/PCDPreviewProvider.m -- the spacebar preview, a data-based Quick Look
 * extension.  macOS 15 dropped .qlgenerator, so this replaces
 * src/GeneratePreviewForURL.m around the same reader (src/image.m). */
#import <Cocoa/Cocoa.h>
#import <QuickLookUI/QuickLookUI.h>
#import <PDFKit/PDFKit.h>
#import "image.h"
#import "overview.h"

@interface PCDPreviewProvider : QLPreviewProvider <QLPreviewingController>
@end

@implementation PCDPreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *, NSError *))handler
{
    NSString *path = [[request fileURL] path];
    if (PCDIsOverview(path)) {
        QLPreviewReply *reply = [[[QLPreviewReply alloc]
            initForPDFWithPageSize:PCDOverviewPageSize()
             documentCreationBlock:^PDFDocument *(QLPreviewReply *r, NSError **err) {
                return PCDOverviewDocument(path);
            }] autorelease];
        handler(reply, nil);
        return;
    }
    pcdReader *reader = [[pcdReader alloc] init];
    /* the spacebar: 16Base, or the highest resolution the Pac holds */
    CGImageRef image = [reader loadPCD:(CFStringRef) [[request fileURL] path] :5];
    if (image == NULL) {
        handler(nil, [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSFileReadCorruptFileError userInfo:nil]);
        [reader release];
        return;
    }
    CGImageRetain(image);
    const CGSize size = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    QLPreviewReply *reply = [[[QLPreviewReply alloc] initWithContextSize:size isBitmap:YES
        drawingBlock:^BOOL(CGContextRef ctx, QLPreviewReply *r, NSError **err) {
            CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), image);
            CGImageRelease(image);
            return YES;
        }] autorelease];
    handler(reply, nil);
    [reader release];
}

@end
