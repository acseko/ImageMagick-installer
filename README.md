# ImageMagick-installer

Goal is to create an ImageMagick installer, which can be installed on rhel8, without installing any AGPL licensed package.

AGPL licensed packages:
 - urw-base35-fonts

 - graphviz depends on urw-base35-fonts

 - libwmf depends on urw-base35-fonts

These dependencies have been removed.

