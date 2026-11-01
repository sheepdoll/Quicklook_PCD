/* ext/PCDPreviewProvider.m -- the spacebar preview, a data-based Quick Look
 * extension.  macOS 15 dropped .qlgenerator, so this replaces
 * src/GeneratePreviewForURL.m around the same reader (src/image.m). */
#import <Cocoa/Cocoa.h>
#import <QuickLookUI/QuickLookUI.h>
#import "image.h"

@interface PCDPreviewProvider : QLPreviewProvider <QLPreviewingController>
@end

@implementation PCDPreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *, NSError *))handler
{
    pcdReader *reader = [[pcdReader alloc] init];
    CGImageRef image = [reader loadPCD:(CFStringRef) [[request fileURL] path] :3];
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
