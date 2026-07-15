#!/usr/bin/env bash
# build-dmg.sh — Archive, export with Developer ID, and package LidBoot as a DMG.
#
# Usage:
#   ./scripts/build-dmg.sh
#
# Output:
#   dist/LidBoot-<version>.dmg
#
# The DMG is signed but NOT yet notarized — run ./scripts/notarize.sh on the
# result. Un-notarized builds are effectively undistributable on macOS 15+,
# which removed the Control-click Gatekeeper bypass.
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="LidBoot"
PROJECT="LidBoot.xcodeproj"
BUILD_DIR="build/release"
ARCHIVE="${BUILD_DIR}/LidBoot.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
DIST_DIR="dist"

# project.yml is the source of truth for the project file.
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "✗ xcodegen not found (brew install xcodegen)" >&2
    exit 1
fi
echo "▶ Generating project from project.yml…"
xcodegen generate

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" App/Info.plist 2>/dev/null || true)
if [[ -z "${VERSION}" || "${VERSION}" == *"\$("* ]]; then
    # Info.plist uses a build-setting variable, so read the real value from project.yml.
    VERSION=$(grep -m1 "MARKETING_VERSION:" project.yml | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/')
fi
echo "▶ Version: ${VERSION}"

echo "▶ Running tests before packaging…"
swift test

rm -rf "${ARCHIVE}" "${EXPORT_DIR}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

echo "▶ Archiving…"
xcodebuild archive \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE}" \
    -destination 'generic/platform=macOS' \
    | grep -E "error:|warning:|ARCHIVE" || true

echo "▶ Exporting with Developer ID…"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    | grep -E "error:|EXPORT" || true

APP="${EXPORT_DIR}/LidBoot.app"
[[ -d "${APP}" ]] || { echo "✗ Export failed: ${APP} missing" >&2; exit 1; }

echo "▶ Verifying signature and hardened runtime…"
codesign --verify --deep --strict --verbose=2 "${APP}"
# The runtime flag is required for notarization; fail early rather than at Apple.
codesign -d --verbose=2 "${APP}" 2>&1 | grep -q "flags=.*runtime" \
    || { echo "✗ Hardened runtime missing — notarization would reject this" >&2; exit 1; }
# The sandbox must stay OFF or the app cannot read NVRAM at all.
if codesign -d --entitlements - --xml "${APP}" 2>/dev/null | plutil -convert xml1 -o - - 2>/dev/null | grep -A1 "app-sandbox" | grep -q "<true/>"; then
    echo "✗ App Sandbox is enabled — LidBoot cannot read or write NVRAM sandboxed" >&2
    exit 1
fi

DMG="${DIST_DIR}/LidBoot-${VERSION}.dmg"
rm -f "${DMG}"

echo "▶ Building DMG…"
if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
        --volname "LidBoot ${VERSION}" \
        --window-pos 200 120 \
        --window-size 520 320 \
        --icon-size 100 \
        --icon "LidBoot.app" 130 150 \
        --app-drop-link 390 150 \
        --no-internet-enable \
        "${DMG}" "${APP}" \
    || true   # create-dmg exits non-zero on cosmetic AppleScript hiccups
else
    echo "  create-dmg not found (brew install create-dmg); falling back to hdiutil"
    hdiutil create -volname "LidBoot ${VERSION}" -srcfolder "${APP}" -ov -format UDZO "${DMG}"
fi

[[ -f "${DMG}" ]] || { echo "✗ DMG not created" >&2; exit 1; }

echo "▶ Signing the DMG…"
codesign --force --sign "Developer ID Application" --timestamp "${DMG}"

echo
echo "✅ Built ${DMG}"
echo "   Next: ./scripts/notarize.sh ${DMG}"
