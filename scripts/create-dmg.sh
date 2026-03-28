#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/ScreenBlocker.xcodeproj}"
SCHEME="${SCHEME:-ScreenBlocker}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_DIR/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_NAME="${APP_NAME:-ScreenBlocker}"

mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -rf "$DERIVED_DATA_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build \
  CODE_SIGNING_ALLOWED=NO

APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found at: $APP_BUNDLE" >&2
  exit 1
fi

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
SHORT_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null || echo "0.1.0"
)"
BUILD_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || echo "1"
)"

DMG_BASENAME="$APP_NAME-$SHORT_VERSION"
if [[ -n "$BUILD_VERSION" && "$BUILD_VERSION" != "$SHORT_VERSION" ]]; then
  DMG_BASENAME="$DMG_BASENAME-$BUILD_VERSION"
fi

DMG_PATH="$DIST_DIR/$DMG_BASENAME.dmg"
rm -f "$DMG_PATH"

STAGING_DIR="$(mktemp -d "$BUILD_DIR/dmg-staging.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  >/dev/null

echo "Created $DMG_PATH"
