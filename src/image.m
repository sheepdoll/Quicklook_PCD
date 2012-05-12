/*
 *  image.m
 *  Quicklook-PCD
 * 
 * Copyright (C) 2008-2012 Julie Porter
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
 */
#include <stdio.h>
#import "image.h"


@implementation pcdReader


- (void) AllocYCC
{
    
    register int y;
    
    /*
     * first, allocate tons of memory
     */
    orig_y = (uint8 **) malloc(sizeof(uint8 *) * height);
    for (y = 0; y < height; y++) {
        orig_y[y] = (uint8 *) malloc(sizeof(uint8) * width);
    }
    
    orig_cr = (uint8 **) malloc(sizeof(uint8 *) * (height/2));
    for (y = 0; y < height/2; y++) {
        orig_cr[y] = (uint8 *) malloc(sizeof(uint8) * (width >> 1));
    }
    
    orig_cb = (uint8 **) malloc(sizeof(uint8 *) * (height/2));
    for (y = 0; y < height/2; y++) {
        orig_cb[y] = (uint8 *) malloc(sizeof(uint8) * (width >> 1));
    }
    
    /* allocate YUV memory */
#if  PSCS
    Y = (double **) malloc(sizeof(double *) * height);
    for (y = 0; y < height; y++) {
        Y[y] = (double *) malloc(sizeof(double) * width);
    }
    
    U = (double **) malloc(sizeof(double *) * height);
    for (y = 0; y < height; y++) {
        U[y] = (double *) malloc(sizeof(double) * width);
    }
    
    V = (double **) malloc(sizeof(double *) * height);
    for (y = 0; y < height; y++) {
        V[y] = (double *) malloc(sizeof(double) * width);
    }
#else    
    Y = (int **) malloc(sizeof(int *) * height);
    for (y = 0; y < height; y++) {
        Y[y] = (int *) malloc(sizeof(int) * width);
    }
    
    U = (int **) malloc(sizeof(int *) * height);
    for (y = 0; y < height; y++) {
        U[y] = (int *) malloc(sizeof(int) * width);
    }
    
    V = (int **) malloc(sizeof(int *) * height);
    for (y = 0; y < height; y++) {
        V[y] = (int *) malloc(sizeof(int) * width);
    }
#endif
    
   
    /* allocate rgb memory */
    
    red = (uint8 **) malloc(sizeof(uint8 *) * height);
    for (y = 0; y < height; y++) {
        red[y] = (uint8 *) malloc(sizeof(uint8) * width);
    }
    
    green = (uint8 **) malloc(sizeof(uint8 *) * height);
    for (y = 0; y < height; y++) {
        green[y] = (uint8 *) malloc(sizeof(uint8) * width);
    }
    
    blue = (uint8 **) malloc(sizeof(uint8 *) * height);
    for (y = 0; y < height; y++) {
        blue[y] = (uint8 *) malloc(sizeof(uint8) * width);
    }


    
}

- (void) FreeYCC
{
    
    register int y;
    
    /*
     * last, clean up tons of memory
     */
    for (y = 0; y < height; y++) {
        free(orig_y[y]);
    }
    free(orig_y);
    for (y = 0; y < height/2; y++) {
        free(orig_cr[y]);
    }
    free(orig_cr);

    for (y = 0; y < height/2; y++) {
        free(orig_cb[y]);
    }
    free(orig_cb);
    
    /* deallocate YUV memory */
    
    for (y = 0; y < height; y++) {
        free(Y[y]);
    }
    free(Y);
    
    for (y = 0; y < height; y++) {
        free(U[y]);
    }
    free(U);

    for (y = 0; y < height; y++) {
        free(V[y]);
    }
    free(V);

    
    /* deallocate rgb memory */
    
    for (y = 0; y < height; y++) {
        free(red[y]);
    }
    free(red);
    
    for (y = 0; y < height; y++) {
        free(green[y]);
    }
    free(green);
    
    for (y = 0; y < height; y++) {
        free(blue[y]);
    }
    free(blue);
}






- (CGImageRef)loadPCD:(CFStringRef)filenameCF: (unsigned int) subimage
{
    FILE   *inimage;        // input file
 
    unsigned char *imageDataPtr;
#if PSCS
    double   tempR, tempG, tempB;
#else
    int   tempR, tempG, tempB;
#endif
    int     r, g, b;
    int     x, y;
    
    long offset;
    
    unsigned char
    /*  *chroma1,
     *chroma2, 
     *luma; */
    *header;

    
    
    unsigned int
    i,
    number_images,
    overview,
    rotate,
    status;
    
    
    // const char *filename = CFStringGetCStringPtr(filenameCF, CFStringGetSystemEncoding());
    char *fullPath;
    char filename[512];;
    
    Boolean conversionResult;
    CFStringEncoding encodingMethod;

    
    NSLog(@"ImageClass for photoCD Image Pac preview files");
    
    //height = 48;
    //width = 64;

    // This is for ensuring safer operation. When CFStringGetCStringPtr() fails,
    // it tries CFStringGetCString().
     
    encodingMethod = CFStringGetFastestEncoding(filenameCF);
     
    // 1st try for English system
    fullPath = (char*)CFStringGetCStringPtr(filenameCF, encodingMethod);

    // for safer operation.
    if( fullPath == NULL )
    {
        CFIndex length = CFStringGetMaximumSizeOfFileSystemRepresentation(filenameCF);
        fullPath = (char *)malloc( length + 1 );
        conversionResult = CFStringGetFileSystemRepresentation(filenameCF, fullPath, length);
        
        strcpy( filename, fullPath );
        
        free( fullPath );
    }
    else
        strcpy( filename, fullPath );
    
    
    // open image read-only
    inimage = fopen( filename,"r");
    
    // file cannot be opened
    if ( inimage == NULL )
    {
        NSLog(@"ERROR: The file '%@' cannot be opened!\n", filenameCF);
        return NULL;
    }
    
    
        
 
    // subimage = gSubimage;
        
        
    header = (unsigned char *) malloc(3*0x800*sizeof(unsigned char));
    if (header == (unsigned char *) NULL)
    {
        NSLog(@"cant allocate PCD header %s", filename);
        return NULL;
    }

    status = fread(header,1,3*0x800,inimage);
    
    overview=strncmp((char *) header,"PCD_OPA",7) == 0;
    if ((status == 0) ||
            ((strncmp((char *) header+0x800,"PCD",3) != 0) && !overview))
    {
        NSLog(@"CorruptImageWarning,Not a PCD image file");
        return NULL;
    }
    
    rotate=header[0x0e02] & 0x03;
        
    number_images=(header[10] << 8) | header[11];
        
    free((char *) header);
    
    /*
     Determine resolution by subimage specification.
    */
        
    /* subimage=3; */
        
    if (overview)
        subimage=1;
        
    /*
        Initialize image structure.
    */
    width=192;
    height=128;
    
    for (i=1; i < subimage; i++) /* min(subimage,3) */
    {
        width<<=1;
        height<<=1;
    }
    /*
    
     *x_size = width;
     *y_size = height;
        
     for ( ; i < subimage; i++)
     {
         *x_size<<=1;
         *y_size<<=1;
     }
    */
 
    
    
    [ self AllocYCC ];
    
        
    /*
     Advance to image data.
    */
    
    offset=93;
    
    if (overview)
        offset=2;
    else
        if (subimage == 2)
            offset=20;
        else
            if (subimage <= 1)
                offset=1;
    for (i=0; i < (offset*0x800); i++)
        (void) fgetc(inimage);
        
   // y = orig_y;
    /*c1=chroma1; */
    /*c2=chroma2; */
    
    nx = ny = 0;
    
    for (i=0; i < height/2; i++)
    {
        fread(orig_y[ny],1,width,inimage);
        //y+=width;
        ny += 1;
        fread(orig_y[ny],1,width,inimage);
        //y+=width;
        ny += 1;
        
        fread(orig_cb[i],1,width >> 1,inimage);
        fread(orig_cr[i],1,width >> 1,inimage);
            
        //fread((char *) chromaskip,1,width >> 1,inimage);
        /*c1+=width;*/
        //fread((char *) chromaskip,1,width >> 1,inimage);
        /* c2+=width; */
    }
        
    fclose(inimage);

    channels = 3;
    
    NSLog(@"Image has been read and has size %dx%dx%d\n",width, height, channels);
    
    nx = width;
    ny = height;
    spp = 3;
    bps = 8;
    
    NSString* csp = NSDeviceRGBColorSpace;
    
    
    
    NSBitmapImageRep *image2 = NULL;
    image2 = [[NSBitmapImageRep alloc]
              initWithBitmapDataPlanes:NULL
              pixelsWide:nx pixelsHigh:ny bitsPerSample:bps
              samplesPerPixel:spp hasAlpha:NO isPlanar:NO
              colorSpaceName:csp
              bytesPerRow:nx*spp*(bps/8) bitsPerPixel:spp*bps ];
    
    if (image2 == NULL)
    {
        NSLog(@"Image cannot be constructed by NSBitmapImageRep!");
        return NULL;
    }
    
    imageDataPtr = (unsigned char *) [image2 bitmapData];
    
    NSLog(@"converting data from YCC to YUV");
    
    // normalize colorspace from YCC to YUV (-128 to 128)

    for ( y = 0; y < height/2; y ++ )
        for ( x = 0; x < width >> 1; x ++ )
        {
            //C2 chroma2 j get i get 137 sub def
            //C1 chroma1 j get i get 156 sub def
#if  PSCS
            // this is the old postscript color space conversion
//          U[y][x] = orig_cb[y][x] - 137;
//          V[y][x] = orig_cr[y][x] - 156;

// a slightly different color space from http://www5.informatik.tu-muenchen.de/lehre/vorlesungen/graphik/info/csc/COL_34.htm
//          Chroma2         = 1.8215 * (Chroma2_8bit - 137)
//          Chroma1         = 2.2179 * (Chroma1_8bit - 156)
            U[y][x] = 1.8215 * (orig_cb[y][x] - 137);
            V[y][x] = 2.2179 * (orig_cr[y][x] - 156);
            
#else
            U[y][x] = orig_cb[y][x] - 128;
            V[y][x] = orig_cr[y][x] - 128;
#endif
        }
    
    for ( y = 0; y < height; y ++ )
        for ( x = 0; x < width; x ++ )
        {
            //Y  luma        j get i get def
#if PSCS
//         Luma            = 1.3584 * Luma_8bit
           Y[y][x] = orig_y[y][x] * 1.3584; 
#else
           Y[y][x] = orig_y[y][x] - 16;
#endif
       }
    
    for ( y = 0; y < height; y++ )
        for ( x = 0; x < width; x++ )
        {
            /* look at yuvtoppm source for explanation */
            // basically this does a color vector translation
            // there should be a Quartz colorspace that does this
            // as part of the device space, like in postscript
            // but docs are sketcy on that
            
// For display primaries that are, or are very close to, CCIR Recommendation 709 primaries in their chromaticities, then
#if PSCS            
//       this is the old postscript color space conversion
//       YCC is scaled by 1.3584.  C1 zero is 156 and C2 is at 137.
            
//       tempR = Y[y][x]            +1.340762*V[y/2][x/2];
//       tempG = Y[y][x]-0.317038*U[y/2][x/2]-0.682243*V[y/2][x/2];
//       tempB = Y[y][x]+1.632639*U[y/2][x/2];

// a slightly different color space from http://www5.informatik.tu-muenchen.de/lehre/vorlesungen/graphik/info/csc/COL_34.htm
  
            tempR = Y[y][x] + V[y/2][x/2];
            tempG = Y[y][x] - 0.194 * U[y/2][x/2] - 0.509 * V[y/2][x/2];
            tempB = Y[y][x] + U[y/2][x/2];
            
// this results in RGB values from 0 to 346 (instead of the more usual 0 to 255) 
// a look-up-table is usually used to convert these through a non-linear function to 8 bit data
   
// since this is used for previews we can either chop the highlights or scale things to fit 
// there is often too much highlight in the  shadows, so dump the lowest 32 values and scale the rest
            
            tempR = (tempR-16) * (255.0/330.0);
            tempG = (tempG-16) * (255.0/330.0);
            tempB = (tempB-16) * (255.0/330.0);
            
            r = CHOP((int)(tempR)); 
            g = CHOP((int)(tempG)); 
            b = CHOP((int)(tempB)); 
#else         
            // YCC
            tempR = 104635*V[y/2][x/2];
            tempG = -25690*U[y/2][x/2] + -53294 * V[y/2][x/2];
            tempB = 132278*U[y/2][x/2];
            
            tempR += (Y[y][x]*76310);
            tempG += (Y[y][x]*76310);
            tempB += (Y[y][x]*76310);
            
            r = CHOP((int)(tempR >> 16));
            g = CHOP((int)(tempG >> 16));
            b = CHOP((int)(tempB >> 16));
#endif            
            red[y][x] = r;  green[y][x] = g;    blue[y][x] = b;
        }
    
    NSLog(@"Constructing RGB image");
    
    for ( y = 0; y < height; y++ )
        for ( x = 0; x < width; x++ )
        {
            *imageDataPtr++ = red[y][x];
            *imageDataPtr++ = green[y][x];
            *imageDataPtr++ = blue[y][x];
        }
    
    NSLog(@"Image constructed and image pointer is %p\n", image2);
    
    [ self FreeYCC ]; 
    
    
    // how do we check for invalid file?
    //return [self load411 ];

    return [image2 CGImage];
}

@end
