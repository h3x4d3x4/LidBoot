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

# NB: capture into a variable rather than piping to `grep -q`. Under
# `set -o pipefail`, grep -q exits at the first match and SIGPIPEs codesign,
# which fails the pipeline even though the check passed.
SIGN_INFO=$(codesign -d --verbose=2 "${APP}" 2>&1 || true)

# The runtime flag is required for notarization; fail here rather than at Apple.
case "${SIGN_INFO}" in
    *"flags="*"runtime"*) echo "  ✓ hardened runtime" ;;
    *) echo "✗ Hardened runtime missing — notarization would reject this" >&2; exit 1 ;;
esac

case "${SIGN_INFO}" in
    *"Developer ID Application"*) echo "  ✓ Developer ID signed" ;;
    *) echo "✗ Not Developer ID signed — Gatekeeper would block this" >&2; exit 1 ;;
esac

# The sandbox must stay OFF or the app cannot read NVRAM at all.
ENTS=$(codesign -d --entitlements - --xml "${APP}" 2>/dev/null || true)
case "${ENTS}" in
    *"app-sandbox"*"<true/>"*)
        echo "✗ App Sandbox is enabled — LidBoot cannot read or write NVRAM sandboxed" >&2
        exit 1 ;;
    *) echo "  ✓ sandbox off (required for NVRAM access)" ;;
esac

# ── Notarize and staple the .app itself, BEFORE packaging ───────────────────
# The DMG gets notarized separately (notarize.sh), but a ticket on the DMG alone
# means the app inside relies on an online Gatekeeper check — a user whose FIRST
# launch happens offline hits friction. Stapling must happen before hdiutil:
# you can't staple inside a read-only image.
find_profile() {
    if [[ -n "${NOTARIZE_PROFILE:-}" ]]; then echo "${NOTARIZE_PROFILE}"; return; fi
    for candidate in hexadexa-notary lidboot-notary observio-notary; do
        xcrun notarytool history --keychain-profile "${candidate}" >/dev/null 2>&1 \
            && { echo "${candidate}"; return; }
    done
}
PROFILE="$(find_profile)"
if [[ -n "${PROFILE}" ]]; then
    echo "▶ Notarizing the app itself (profile: ${PROFILE})…"
    APP_ZIP="${BUILD_DIR}/LidBoot-app.zip"
    rm -f "${APP_ZIP}"
    ditto -c -k --keepParent "${APP}" "${APP_ZIP}"
    xcrun notarytool submit "${APP_ZIP}" --keychain-profile "${PROFILE}" --wait --timeout 30m \
        | grep -E "status:" | tail -1
    xcrun stapler staple "${APP}" >/dev/null
    xcrun stapler validate "${APP}" >/dev/null && echo "  ✓ app stapled — offline first launch covered"
else
    echo "  ⚠ no notarytool profile found — app NOT stapled; the DMG-level ticket"
    echo "    still covers online launches. See notarize.sh header to set one up."
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
