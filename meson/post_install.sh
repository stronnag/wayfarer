#!/bin/sh

ICON_CACHE=${MESON_INSTALL_PREFIX}/share/icons/hicolor

if [ -z "$DESTDIR" ]; then
 echo "Updating gtk icon cache ..."
 gtk-update-icon-cache -qtf $ICON_CACHE
fi
