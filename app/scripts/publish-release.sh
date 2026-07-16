#!/usr/bin/env bash
# publish-release.sh — EdDSA-sign a notarized DMG, attach it to a GitHub release
# on THIS repo, and update the Sparkle appcast at the repo root.
#
# Usage:
#   ./scripts/publish-release.sh 0.4.0 5
#   ./scripts/publish-release.sh 0.4.0 5 --dry-run
#
# Since the source is open, releases and the appcast live in the main repo:
#
#   appcast (canonical): https://raw.githubusercontent.com/h3x4d3x4/LidBoot/main/appcast.xml
#   DMGs:                this repo's GitHub Releases
#
# Prerequisites: DMG built+notarized+stapled; gh authenticated; Sparkle key in
# the login keychain.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?Usage: publish-release.sh <version> <build> [--dry-run]}"
BUILD="${2:?Usage: publish-release.sh <version> <build> [--dry-run]}"
DRY_RUN=false
[[ "${3:-}" == "--dry-run" ]] && DRY_RUN=true

REPO="${LIDBOOT_REPO:-h3x4d3x4/LidBoot}"
DMG="dist/LidBoot-${VERSION}.dmg"
SIGN_UPDATE="build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
WORK="build/appcast"

[[ -f "${DMG}" ]] || { echo "✗ ${DMG} not found — run build-dmg.sh first" >&2; exit 1; }

echo "▶ Checking the DMG is notarized and stapled…"
xcrun stapler validate "${DMG}" >/dev/null 2>&1 \
    || { echo "✗ ${DMG} is not stapled — run ./scripts/notarize.sh first" >&2; exit 1; }
echo "  ✓ stapled"

[[ -x "${SIGN_UPDATE}" ]] || {
    echo "✗ Sparkle's sign_update not found; resolve packages first:" >&2
    echo "    xcodebuild -project LidBoot.xcodeproj -scheme LidBoot -derivedDataPath ./build -resolvePackageDependencies" >&2
    exit 1
}

echo "▶ EdDSA-signing ${DMG}…"
SIG_ATTRS=$("${SIGN_UPDATE}" "${DMG}")
echo "  ${SIG_ATTRS}"

DMG_URL="https://github.com/${REPO}/releases/download/v${VERSION}/LidBoot-${VERSION}.dmg"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

mkdir -p "${WORK}"
ITEM_FILE="${WORK}/item-${VERSION}.xml"
cat > "${ITEM_FILE}" <<XML
        <item>
            <title>${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${BUILD}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
$(cat "scripts/release-notes/${VERSION}.html" 2>/dev/null || echo "                <p>See the release page for details.</p>")
            ]]></description>
            <enclosure url="${DMG_URL}" ${SIG_ATTRS} type="application/octet-stream" />
        </item>
XML

build_appcast() {
    # $1 = existing appcast file (may be absent), $2 = output
    local existing="" items=""
    # Keep prior items EXCEPT any for the version being published: a republish
    # must replace its own item, not stack a stale duplicate beside it.
    [[ -f "$1" ]] && items=$(python3 -c "
import re, sys
s = open('$1').read()
for it in re.findall(r'[ \t]*<item>.*?</item>', s, re.S):
    if '<sparkle:shortVersionString>${VERSION}<' not in it:
        print(it)
" 2>/dev/null || true)
    cat > "$2" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>LidBoot</title>
        <link>https://raw.githubusercontent.com/${REPO}/main/appcast.xml</link>
        <description>Updates for LidBoot</description>
        <language>en</language>
$(cat "${ITEM_FILE}")
${items}
    </channel>
</rss>
XML
}

echo "▶ Building the canonical appcast (repo root)…"
# ../appcast.xml — the repo root, one level above app/.
build_appcast "../appcast.xml" "${WORK}/appcast-new.xml"

if [[ "${DRY_RUN}" == true ]]; then
    echo "— dry run — nothing published. Appcast preview:"
    head -30 "${WORK}/appcast-new.xml"
    exit 0
fi

echo "▶ Creating GitHub release v${VERSION} on ${REPO}…"
gh release create "v${VERSION}" "${DMG}" \
    --repo "${REPO}" \
    --title "LidBoot ${VERSION}" \
    --notes-file "scripts/release-notes/${VERSION}.md" \
    --latest

echo "▶ Committing appcast.xml at the repo root…"
cp "${WORK}/appcast-new.xml" ../appcast.xml
git -C .. add appcast.xml
git -C .. commit -q -m "Appcast: ${VERSION}" || echo "  (no appcast change to commit)"
git -C .. push -q origin main

echo "▶ Verifying…"
sleep 3
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/appcast.xml" 2>/dev/null | grep -q "${VERSION}" \
    && echo "  ✓ canonical feed serves ${VERSION}" \
    || echo "  ⚠ raw CDN lag (~5 min is normal); the repo itself is already correct"

FEED_IN_APP=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" App/Info.plist 2>/dev/null || echo "")
echo "  feed baked into the app: ${FEED_IN_APP}"
[[ "${FEED_IN_APP}" == *"${REPO}"* ]] || echo "  ⚠ the app's SUFeedURL doesn't point at ${REPO}" >&2

echo
echo "✅ Published LidBoot ${VERSION}"
