#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexUsageTracker"
BUNDLE_ID="io.github.berqiamouad.codex-usage-tracker"
MIN_SYSTEM_VERSION="14.0"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
FORMAT="${1:-zip}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
RESOURCE_SOURCE="$ROOT_DIR/Sources/CodexUsageTracker/Resources"
DMG_RESOURCE_SOURCE="$RESOURCE_SOURCE/DMG"
ARCHIVE_ZIP="$DIST_DIR/$APP_NAME-macOS.zip"
ARCHIVE_DMG="$DIST_DIR/$APP_NAME-macOS.dmg"
DMG_STAGING="$DIST_DIR/dmg-staging"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"

usage() {
  cat <<EOF
usage: $0 [zip|dmg|both]

Environment variables:
  VERSION=1.0.0
  BUILD_NUMBER=1
  CODE_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
  NOTARYTOOL_PROFILE="notarytool-profile-name"
EOF
}

build_bundle() {
  swift build -c release
  local build_binary
  build_binary="$(swift build -c release --show-bin-path)/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  chmod +x "$APP_BINARY"
  cp "$RESOURCE_SOURCE/CodexUsageTracker.icns" "$APP_RESOURCES/"
  cp "$RESOURCE_SOURCE/CodexUsageTrackerMenuBar.png" "$APP_RESOURCES/"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>CodexUsageTracker</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

sign_bundle_if_configured() {
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "Ad-hoc signing bundle: CODE_SIGN_IDENTITY is not set."
    codesign --force --deep --sign - "$APP_BUNDLE"
    codesign --verify --deep --strict "$APP_BUNDLE"
    return
  fi

  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"
}

notarize_if_configured() {
  local artifact="$1"

  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "Skipping notarization: bundle is unsigned."
    return
  fi
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "Skipping notarization: NOTARYTOOL_PROFILE is not set."
    return
  fi

  xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" --wait

  if [[ "$artifact" == *.dmg ]]; then
    xcrun stapler staple "$artifact"
  else
    xcrun stapler staple "$APP_BUNDLE"
  fi
}

package_zip() {
  rm -f "$ARCHIVE_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_ZIP"
  notarize_if_configured "$ARCHIVE_ZIP"
}

package_dmg() {
  rm -rf "$DMG_STAGING"
  rm -f "$ARCHIVE_DMG"
  mkdir -p "$DMG_STAGING"
  cp -R "$APP_BUNDLE" "$DMG_STAGING/"
  ln -s /Applications "$DMG_STAGING/Applications"

  if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
      --volname "$APP_NAME" \
      --volicon "$DMG_RESOURCE_SOURCE/VolumeIcon.icns" \
      --background "$DMG_RESOURCE_SOURCE/dmg-background.png" \
      --window-size 660 420 \
      --icon-size 128 \
      --icon "$APP_NAME.app" 150 216 \
      --app-drop-link 510 216 \
      "$ARCHIVE_DMG" \
      "$DMG_STAGING"
  else
    hdiutil create \
      -volname "$APP_NAME" \
      -srcfolder "$DMG_STAGING" \
      -ov \
      -format UDZO \
      "$ARCHIVE_DMG"
  fi

  notarize_if_configured "$ARCHIVE_DMG"
}

main() {
  case "$FORMAT" in
    zip|dmg|both) ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac

  mkdir -p "$DIST_DIR"
  build_bundle
  sign_bundle_if_configured

  case "$FORMAT" in
    zip)
      package_zip
      ;;
    dmg)
      package_dmg
      ;;
    both)
      package_zip
      package_dmg
      ;;
  esac

  echo "Release artifacts written to $DIST_DIR"
}

main "$@"
