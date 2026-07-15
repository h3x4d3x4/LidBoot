#!/usr/bin/env bash
# notarize.sh — Submit a DMG to Apple's notary service and staple the ticket.
#
# Usage:
#   ./scripts/notarize.sh dist/LidBoot-0.1.0.dmg
#
# ONE-TIME SETUP (interactive — you must run this yourself, it needs your
# app-specific password from appleid.apple.com):
#
#   xcrun notarytool store-credentials "lidboot-notary" \
#       --apple-id "your-apple-id@example.com" \
#       --team-id "632VXL3W66" \
#       --password "<app-specific-password>"
#
# Why this is not optional: macOS 15 removed the Control-click Gatekeeper
# bypass, and 15.1 tightened it further. Without notarization users must dig
# through System Settings > Privacy & Security to run the app at all.
set -euo pipefail

DMG="${1:?Usage: notarize.sh <path/to/LidBoot.dmg>}"
PROFILE="${NOTARIZE_PROFILE:-lidboot-notary}"

[[ -f "${DMG}" ]] || { echo "✗ No such file: ${DMG}" >&2; exit 1; }

if ! xcrun notarytool history --keychain-profile "${PROFILE}" >/dev/null 2>&1; then
    echo "✗ Keychain profile '${PROFILE}' not found." >&2
    echo "  Run the one-time store-credentials command in this script's header." >&2
    exit 1
fi

echo "▶ Submitting ${DMG} for notarization…"
xcrun notarytool submit "${DMG}" \
    --keychain-profile "${PROFILE}" \
    --wait \
    --timeout 30m

echo "▶ Stapling notarization ticket…"
xcrun stapler staple "${DMG}"

echo "▶ Verifying the staple survives offline…"
xcrun stapler validate "${DMG}"

echo "▶ Running Gatekeeper assessment…"
spctl --assess --type open --context context:primary-signature --verbose "${DMG}" \
    && echo "✅ Gatekeeper: OK"

echo
echo "✅ Notarized and stapled: ${DMG}"
