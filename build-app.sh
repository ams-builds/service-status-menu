#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Service Status"
EXECUTABLE_NAME="ServiceStatusMenu"
OUTPUT_DIRECTORY="$ROOT/dist"
APP_BUNDLE="$OUTPUT_DIRECTORY/$APP_NAME.app"

printf 'Building %s in release mode…\n' "$APP_NAME"
swift build --package-path "$ROOT" -c release
BIN_DIRECTORY="$(swift build --package-path "$ROOT" -c release --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIRECTORY/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Ad-hoc signing is sufficient for running a personal app on this Mac.
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

printf '\nBuilt application:\n%s\n' "$APP_BUNDLE"
printf '\nRun it with:\nopen "%s"\n' "$APP_BUNDLE"
