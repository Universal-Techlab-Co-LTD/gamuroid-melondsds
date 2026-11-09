#!/usr/bin/env bash
# Packages a built melondsds_libretro.dylib as melondsds.libretro.framework in the layout the
# Gamuroid app embeds (Cores/melondsds.libretro.framework):
#   melondsds.libretro.framework/
#     Info.plist          (same keys as the app's framework; MinimumOSVersion 15.0)
#     melondsds.libretro  (Mach-O, install name @rpath/melondsds_libretro.framework/melondsds_libretro,
#                          the same install name the app's current framework carries)
# plus melondsds.libretro.framework.dSYM next to it. Not code-signed: Xcode signs on embed.
#
# Usage: scripts/package_framework.sh <built dylib> <output dir>
set -euo pipefail

DYLIB="$1"
OUTDIR="$2"
FW="$OUTDIR/melondsds.libretro.framework"
DSYM="$OUTDIR/melondsds.libretro.framework.dSYM"
INSTALL_NAME="@rpath/melondsds_libretro.framework/melondsds_libretro"
VERSION="1.4.0"

rm -rf "$FW" "$DSYM"
mkdir -p "$FW"

cp "$DYLIB" "$FW/melondsds.libretro"
xcrun install_name_tool -id "$INSTALL_NAME" "$FW/melondsds.libretro"

# Debug info first (the LTO object kept by -object_path_lto holds the DWARF), then strip local symbols.
xcrun dsymutil "$FW/melondsds.libretro" -o "$DSYM"
xcrun strip -x "$FW/melondsds.libretro"

cat > "$FW/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>melondsds.libretro</string>
	<key>CFBundleIdentifier</key>
	<string>melondsds.libretro</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>melondsds.libretro</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>MinimumOSVersion</key>
	<string>15.0</string>
</dict>
</plist>
EOF
plutil -lint "$FW/Info.plist" >/dev/null

echo "FRAMEWORK: $FW"
echo "DSYM: $DSYM"
shasum -a 256 "$FW/melondsds.libretro"
xcrun dwarfdump --uuid "$FW/melondsds.libretro"
xcrun dwarfdump --uuid "$DSYM"
