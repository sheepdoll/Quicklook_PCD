# Quicklook_PCD -- a Quick Look extension for Photo CD Image Pacs, Base only.
# clang and the Command Line Tools alone; no Xcode, no project file.
#
#   make            build build/QuicklookPCD.app
#   make install    move it to ~/Applications and register it
#   make refresh    restart the agent and Finder after an install, if icons or
#                   the spacebar misbehave
#   make uninstall  undo the install
#
# macOS 15 dropped .qlgenerator, so src/main.c and src/Generate*ForURL.m (kept
# for the record, with the Xcode project) are not built.  src/image.m is the
# reader, with its C1 / C2 offsets corrected.

APP    = build/QuicklookPCD.app
DEST   = $(HOME)/Applications
LSREG  = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
CFLAGS = -O2 -mmacosx-version-min=12.0 -fapplication-extension -Isrc -Wno-deprecated-declarations
LIBS   = -framework Cocoa -framework QuickLookThumbnailing -framework QuickLookUI -framework PDFKit

all: $(APP)

$(APP): ext/host.m ext/Host-Info.plist src/image.m src/image.h ext/*.m ext/*-Info.plist ext/sandbox.entitlements
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp ext/Host-Info.plist $(APP)/Contents/Info.plist
	clang -O2 -mmacosx-version-min=12.0 ext/host.m -o $(APP)/Contents/MacOS/QuicklookPCD
	for e in Preview Thumbnail; do \
	  d=$(APP)/Contents/PlugIns/PCD$$e.appex/Contents; \
	  mkdir -p $$d/MacOS; \
	  cp ext/$$e-Info.plist $$d/Info.plist; \
	  clang $(CFLAGS) $(LIBS) -e _NSExtensionMain -Iext ext/PCD$${e}Provider.m ext/overview.m src/image.m -o $$d/MacOS/PCD$$e || exit 1; \
	  codesign -s - -f --entitlements ext/sandbox.entitlements $(APP)/Contents/PlugIns/PCD$$e.appex || exit 1; \
	done
	codesign -s - -f $(APP)

install: all
	mkdir -p $(DEST)
	rm -rf $(DEST)/QuicklookPCD.app
	# moved, not copied: a second registered copy with the same bundle IDs
	# is the likely reason macOS dropped both extensions on 2026-11-01
	-$(LSREG) -u $(APP)
	mv $(APP) $(DEST)/
	$(LSREG) -f $(DEST)/QuicklookPCD.app
	pluginkit -a $(DEST)/QuicklookPCD.app/Contents/PlugIns/PCDPreview.appex
	pluginkit -a $(DEST)/QuicklookPCD.app/Contents/PlugIns/PCDThumbnail.appex
	qlmanage -r >/dev/null 2>&1; qlmanage -r cache >/dev/null 2>&1; true
	@echo "Installed.  If icons or the spacebar misbehave: make refresh"

refresh:
	# by full path, and -KILL: on 2026-11-01 it outlived killall and a plain pkill,
	# and only a new agent stopped sending .PCD to Apple's image extension
	-pkill -KILL -f com.apple.quicklook.ThumbnailsAgent
	-killall Finder

uninstall:
	-pluginkit -r $(DEST)/QuicklookPCD.app/Contents/PlugIns/PCDPreview.appex
	-pluginkit -r $(DEST)/QuicklookPCD.app/Contents/PlugIns/PCDThumbnail.appex
	-$(LSREG) -u $(DEST)/QuicklookPCD.app
	rm -rf $(DEST)/QuicklookPCD.app

clean:
	rm -rf build

.PHONY: all install refresh uninstall clean
