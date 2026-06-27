#!/bin/sh
set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"

# Configure the AppImage
export ICON=kaimen.png
export DESKTOP=/usr/share/applications/kaimen.desktop
export OUTPATH=./dist
export OUTNAME=Kaimen.AppImage

# Download and run quick-sharun
wget "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun

# Bundle the application
./quick-sharun ~/bin/Kaimen

# Create the AppImage
./quick-sharun --make-appimage
