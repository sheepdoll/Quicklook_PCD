# Overview
Quick Look for Kodak Photo CD Image Pacs (`.PCD`): Finder thumbnails, Gallery view and the
spacebar preview, at Base resolution (768 x 512) only.  4Base and up are Huffman coded and are
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
    make install    # copies it to ~/Applications and registers it
    make uninstall

Built and run on macOS 26.5.1.  Not yet tried on other versions.

If previews do not appear, check System Settings, General, Login Items & Extensions, Quick Look.
`qlmanage -m` does not list extensions; use `pluginkit -mAv | grep kodak`.
macOS caches thumbnails: after a rebuild run `qlmanage -r cache` and relaunch Finder.  A request
in the first few seconds after `make install` can fail.

# Fixed in this version
* The C1 and C2 chroma offsets and scales were swapped, which left everything with a blue-teal cast.

# Known
* Previews are dim on purpose: `255/330` in `src/image.m` keeps the highlights above white.
* The `rotate` flag in the Image Pac header is read but not applied.

# To do
* Huffman decoding, for 4Base and up.

# Credits
Based on Andreas Steinel's PFM viewer.  GPL, see gpl.txt.
