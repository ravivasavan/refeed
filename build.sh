#!/bin/sh
# Builds Refeed.app and installs it in ~/Applications.
set -e
cd "$(dirname "$0")"
APP="build/Refeed.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macos14 main.swift -o "$APP/Contents/MacOS/Refeed"
cp Info.plist "$APP/Contents/Info.plist"
[ -d icon/AppIcon.iconset ] || xcrun swift icon/make-icon.swift
iconutil -c icns icon/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
rm -rf "$HOME/Applications/Refeed.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installed: $HOME/Applications/Refeed.app"
