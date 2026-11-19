#!/bin/sh
# Builds Presenza.app (Apple silicon + Intel, macOS 14 or later), signs it and runs the self-check.
#
#   ./build.sh       just the app
#   ./build.sh dmg   also dist/Presenza-<version>.dmg, to share
#
# Signed ad hoc: on another Mac Gatekeeper blocks it until the user allows it once
# (Privacy & Security → Open Anyway). A Developer ID plus notarization removes that.
set -e
cd "$(dirname "$0")"
APP=Presenza.app

rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build
cp Info.plist "$APP/Contents/"
plutil -lint -s Info.plist ./*.lproj/*.strings
cp -R en.lproj it.lproj "$APP/Contents/Resources/"
# Liquid Glass icon (Assets.car) on macOS 26, AppIcon.icns before. Absolute paths: actool
# resolves relative ones against its own background process, not this folder.
xcrun actool "$PWD/AppIcon.icon" --compile "$PWD/$APP/Contents/Resources" --platform macosx \
  --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$PWD/build/icon.plist" >/dev/null
[ -f "$APP/Contents/Resources/AppIcon.icns" ] || { echo "actool did not produce the icon" >&2; exit 1; }

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14.0" *.swift -o "build/Presenza-$arch"
done
lipo -create build/Presenza-arm64 build/Presenza-x86_64 -output "$APP/Contents/MacOS/Presenza"

# hardened runtime + camera entitlement: what notarization will ask for
codesign --force --options runtime --entitlements Presenza.entitlements --sign - "$APP"
"$APP/Contents/MacOS/Presenza" --selftest

if [ "${1:-}" = dmg ]; then
  version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
  mkdir -p build/dmg dist
  cp -R "$APP" build/dmg/
  ln -s /Applications build/dmg/Applications
  hdiutil create -quiet -volname Presenza -srcfolder build/dmg -ov -format UDZO "dist/Presenza-$version.dmg"
  echo "dist/Presenza-$version.dmg"
fi
