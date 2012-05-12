# Overview
This piece of code enables [Apple QuickLook](http://en.wikipedia.org/wiki/Quick_Look) to open

* PCD files

# this code is designed to build through Xcode 4 or later.  The existing target is to build for lion.  

To debug the tool qlmanage needs to be in the projects path/


#Installation
There is a build step which should install the target as the last build step.  If this does not work. Find the target Quicklook-PCD  and move into the following directory
    ~/Library/Quickly
(you may have to create this folder). Finder may need to be restarted in order to be able to use this QuickLook plugin. This can be done by either killing Finder in the terminal (killall Finder) or logout/login.

#Credits
This code is based on Andreas Steinel's PCM viewer  The "Generate(*)ForURL source is only slightly modified from lnxbil-quicklook-pfm-23d2205

