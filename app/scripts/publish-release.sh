#!/usr/bin/env bash
# publish-release.sh — EdDSA-sign a notarized DMG, publish it to the public
# releases repo, and update the Sparkle appcast.
#
# Usage:
#   ./scripts/publish-release.sh 0.2.0 2
#   ./scripts/publish-release.sh 0.2.0 2 --dry-run
#
# Model (same as Observio):
#
#   this repo (private) ──build, sign, notarize locally──► publish-release.sh
#                                                              │
#                        ┌─────────────────────────────────────┴───────────┐
#                        ▼                                                 ▼
#            public repo Release assets                        public repo appcast.xml
#            (LidBoot-<version>.dmg)                           (the canonical feed)
#                        ▲                                                 ▲
#                        │                    raw.githubusercontent.com/.../appcast.xml
#                        │                    (the app reads this URL directly)
#                   app downloads here (public, no auth)
#
# The app needs no token: integrity comes from the EdDSA signature
# (SUPublicEDKey in Info.plist), not from the feed being private.
#
# Prerequisites:
#   - DMG already built, signed AND notarized+stapled (build-dmg.sh, notarize.sh)
#   - gh authenticated with access to the releases repo
#   - Sparkle signing key in the login keychain (Sparkle's generate_keys)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?Usage: publish-release.sh <version> <build> [--dry-run]}"
BUILD="${2:?Usage: publish-release.sh <version> <build> [--dry-run]}"
DRY_RUN=false
[[ "${3:-}" == "--dry-run" ]] && DRY_RUN=true

RELEASES_REPO="${LIDBOOT_RELEASES_REPO:-h3x4d3x4/LidBoot-Releases}"
DMG="dist/LidBoot-${VERSION}.dmg"
SIGN_UPDATE="build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
WORK="build/appcast"

[[ -f "${DMG}" ]] || { echo "✗ ${DMG} not found — run build-dmg.sh first" >&2; exit 1; }

# A DMG that isn't stapled will trip Gatekeeper on every tester's machine.
echo "▶ Checking the DMG is notarized and stapled…"
xcrun stapler validate "${DMG}" >/dev/null 2>&1 \
    || { echo "✗ ${DMG} is not stapled — run ./scripts/notarize.sh first" >&2; exit 1; }
echo "  ✓ stapled"

[[ -x "${SIGN_UPDATE}" ]] || {
    echo "✗ Sparkle's sign_update not found. Run once to fetch the package:" >&2
    echo "    xcodebuild -project LidBoot.xcodeproj -scheme LidBoot -derivedDataPath ./build -resolvePackageDependencies" >&2
    exit 1
}

echo "▶ EdDSA-signing ${DMG}…"
# Emits: sparkle:edSignature="…" length="…"
SIG_ATTRS=$("${SIGN_UPDATE}" "${DMG}")
echo "  ${SIG_ATTRS}"

DMG_URL="https://github.com/${RELEASES_REPO}/releases/download/v${VERSION}/LidBoot-${VERSION}.dmg"
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

echo "▶ Building appcast.xml…"
APPCAST="${WORK}/appcast.xml"
# Start from the live feed so previous items survive; fall back to a new file.
EXISTING=""
if curl -fsSL "https://raw.githubusercontent.com/${RELEASES_REPO}/main/appcast.xml" -o "${WORK}/existing.xml" 2>/dev/null; then
    # Keep every <item> already published.
    EXISTING=$(sed -n '/<item>/,/<\/item>/p' "${WORK}/existing.xml" 2>/dev/null || true)
    echo "  merged with the existing feed"
else
    echo "  no existing feed — creating a new one"
fi

cat > "${APPCAST}" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>LidBoot</title>
        <link>https://raw.githubusercontent.com/h3x4d3x4/LidBoot-Releases/main/appcast.xml</link>
        <description>Updates for LidBoot</description>
        <language>en</language>
$(cat "${ITEM_FILE}")
${EXISTING}
    </channel>
</rss>
XML

echo "  wrote ${APPCAST}"

if [[ "${DRY_RUN}" == true ]]; then
    echo
    echo "— dry run — nothing published. Appcast preview:"
    cat "${APPCAST}"
    exit 0
fi

if ! gh repo view "${RELEASES_REPO}" >/dev/null 2>&1; then
    echo "✗ Releases repo ${RELEASES_REPO} not found." >&2
    echo "  It must be PUBLIC so the app can fetch the feed without a token:" >&2
    echo "    gh repo create ${RELEASES_REPO} --public" >&2
    exit 1
fi

echo "▶ Creating GitHub release v${VERSION} in ${RELEASES_REPO}…"
gh release create "v${VERSION}" "${DMG}" \
    --repo "${RELEASES_REPO}" \
    --title "LidBoot ${VERSION}" \
    --notes-file "scripts/release-notes/${VERSION}.md" \
    --prerelease

echo "▶ Publishing appcast.xml…"
TMP_CLONE="${WORK}/releases-repo"
rm -rf "${TMP_CLONE}"
gh repo clone "${RELEASES_REPO}" "${TMP_CLONE}" -- --depth 1 --quiet
cp "${APPCAST}" "${TMP_CLONE}/appcast.xml"
git -C "${TMP_CLONE}" add appcast.xml
git -C "${TMP_CLONE}" commit -q -m "LidBoot ${VERSION}"
git -C "${TMP_CLONE}" push -q

echo "▶ Verifying the live feed…"
sleep 3
curl -fsSL "https://raw.githubusercontent.com/${RELEASES_REPO}/main/appcast.xml" | grep -q "${VERSION}" \
    && echo "  ✓ raw feed serves ${VERSION}" \
    || echo "  ⚠ raw feed doesn't show ${VERSION} yet (GitHub caching — retry shortly)"

# The feed the app actually reads is the raw URL above — no redirect in front.
FEED_IN_APP=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" App/Info.plist 2>/dev/null || echo "")
echo "  feed baked into the app: ${FEED_IN_APP}"
if [[ "${FEED_IN_APP}" != *"${RELEASES_REPO}"* ]]; then
    echo "  ⚠ the app's SUFeedURL doesn't point at ${RELEASES_REPO} — updates would not arrive" >&2
fi

echo
echo "✅ Published LidBoot ${VERSION}"
