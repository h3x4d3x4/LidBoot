#!/usr/bin/env bash
# notarize.sh — Submit a DMG to Apple's notary service and staple the ticket.
#
# Usage:
#   ./scripts/notarize.sh dist/LidBoot-0.1.0.dmg
#
# A notarytool profile is just stored credentials for an Apple ID + team — it
# isn't tied to an app. All Hexadexa apps ship under the same Apple ID and team
# (632VXL3W66), so one profile serves all of them; a per-app profile would just
# be a second copy of the same secret under a different name, with no isolation
# (revoking the app-specific password breaks every profile using it anyway).
#
# So we try a few known names rather than demanding a new one. Override with:
#   NOTARIZE_PROFILE=<name> ./scripts/notarize.sh <dmg>
#
# To create one (interactive — needs an app-specific password from
# appleid.apple.com):
#   xcrun notarytool store-credentials "hexadexa-notary" \
#       --apple-id "your-apple-id@example.com" \
#       --team-id "632VXL3W66" \
#       --password "<app-specific-password>"
#
# Why notarizing is not optional: macOS 15 removed the Control-click Gatekeeper
# bypass, and 15.1 tightened it further. Without it users must dig through
# System Settings > Privacy & Security to run the app at all.
set -euo pipefail

DMG="${1:?Usage: notarize.sh <path/to/LidBoot.dmg>}"

[[ -f "${DMG}" ]] || { echo "✗ No such file: ${DMG}" >&2; exit 1; }

find_profile() {
    if [[ -n "${NOTARIZE_PROFILE:-}" ]]; then
        echo "${NOTARIZE_PROFILE}"; return
    fi
    for candidate in hexadexa-notary lidboot-notary observio-notary; do
        if xcrun notarytool history --keychain-profile "${candidate}" >/dev/null 2>&1; then
            echo "${candidate}"; return
        fi
    done
}

PROFILE="$(find_profile)"
if [[ -z "${PROFILE}" ]]; then
    echo "✗ No usable notarytool keychain profile found." >&2
    echo "  Tried: hexadexa-notary, lidboot-notary, observio-notary." >&2
    echo "  Create one with the store-credentials command in this script's header," >&2
    echo "  or set NOTARIZE_PROFILE=<name>." >&2
    exit 1
fi
echo "▶ Using keychain profile: ${PROFILE}"

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
