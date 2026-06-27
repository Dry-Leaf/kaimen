#!/bin/sh
set -eux

cd "$(dirname "$0")"


export ICON=kaimen.png
export DESKTOP=kaimen.desktop
export OUTPATH=./dist
export OUTNAME=Kaimen.AppImage


export BIN="bin/kaimen"

SHARUN="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"


wget "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun


rm -rf ./dist/AppDir/.sharun ./dist/AppDir/AppRun

./quick-sharun ./dist/AppDir ./dist/AppDir/search

./quick-sharun --make-appimage
