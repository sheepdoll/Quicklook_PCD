/* ext/overview.h -- an OVERVIEW.PCD as a PDF of contact-sheet pages. */
#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>

BOOL PCDIsOverview(NSString *path);
CGSize PCDOverviewPageSize(void);
PDFDocument *PCDOverviewDocument(NSString *path);
