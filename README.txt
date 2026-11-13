# Overview
Quick Look for Kodak Photo CD Image Pacs (`.PCD`): Finder thumbnails, Gallery view and the
spacebar preview, at Base resolution (768 x 512) only.  An OVERVIEW.PCD previews as pages of
numbered thumbnails.  4Base and up are Huffman coded and are
not read yet.

macOS 15 (Sequoia) removed `.qlgenerator` support, so the old plug-in no longer loads.  This is
now a pair of app extensions inside a small host app, which also declares the `.PCD` file type.

    src/image.m        the reader
    ext/               the extensions, the host app and their Info.plists
    src/main.c, src/Generate*ForURL.m, Info.plist, Quicklook_PCD.xcodeproj
                       the old plug-in, kept for the record and not built

# Build and install
No Xcode project: clang and the Command Line Tools (`xcode-select --install`), macOS 12 or later.

    make            # build/QuicklookPCD.app, ad-hoc signed
    make install    # moves it to ~/Applications and registers it
    make refresh    # restarts the thumbnail agent and Finder
    make uninstall

Built and run on macOS 26.5.1.  Not yet tried on other versions.

If previews do not appear, check System Settings, General, Login Items & Extensions, Quick Look.
`qlmanage -m` does not list extensions; use `pluginkit -mAv | grep kodak`.
After reinstalling, Finder and the thumbnail agent can hold on to the old extension: icons vanish
or the spacebar gives an error until `make refresh`.  A request in the first few seconds after
`make install` can also fail.  Keep only one copy of the app registered.

# Fixed in this version
* The C1 and C2 chroma offsets and scales were swapped, which left everything with a blue-teal cast.

# Known
* The type is declared as data, not `public.image`: as an image, the thumbnail agent can hand it
  to Apple's image extension, which cannot read it, and the icons go blank.
* `k4050Diagnostics/PCDImageArtifacts/IMG0004.PCD` (SN 0228, fw 3.56, 1999) previews with
  horizontal red bands.  They are in the file, not a reader bug: Base/16, Base/4 and Base, each
  stored in its own sectors, carry the same bands at the same image heights (every 1/8 of the
  frame, plus a cluster around the middle), each a row-wide lift in Y and C2 that fades over
  about 8 Base lines, and the black border lifts too.  [checked 2026-11-02]
* Colour: `pcd_iView.ps`'s `ycbcr2rgb4` (1.164 (Y - 16), C1 about 156, C2 about 137), black at
  stored 16, clamped to 0..255, in both `src/pcdhuff.c` and `src/image.m`.  [2026-11-12]
* The `rotate` flag in the Image Pac header is read but not applied.

# To do
* Huffman decoding, for 4Base and up.

# Credits
Based on Andreas Steinel's PFM viewer.  GPL, see gpl.txt.
