/* ext/PCDThumbnailProvider.m -- Finder icons and Gallery view.  Replaces
 * src/GenerateThumbnailForURL.m around the same reader (src/image.m). */
#import <Cocoa/Cocoa.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import "image.h"

@interface PCDThumbnailProvider : QLThumbnailProvider
@end

@implementation PCDThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply *, NSError *))handler
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
    /* the whole frame inside what was asked for */
    const CGSize max = [request maximumSize];
    const CGFloat w = CGImageGetWidth(image), h = CGImageGetHeight(image);
    const CGFloat k = MIN(max.width / w, max.height / h);
    const CGSize size = CGSizeMake(floor(w * k), floor(h * k));
    handler([QLThumbnailReply replyWithContextSize:size drawingBlock:^BOOL(CGContextRef ctx) {
        /* the context is size x the screen's scale in pixels, and its user space
           is not scaled to match: a Retina icon drawn at `size` fills one quarter */
        const CGRect all = CGContextConvertRectToUserSpace(ctx,
            CGRectMake(0, 0, CGBitmapContextGetWidth(ctx), CGBitmapContextGetHeight(ctx)));
        CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
        CGContextDrawImage(ctx, all, image);
        CGImageRelease(image);
        return YES;
    }], nil);
    [reader release];
}

@end
