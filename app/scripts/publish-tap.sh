#!/usr/bin/env bash
# Publish the LidBoot cask to h3x4d3x4/homebrew-tap.
#
#   scripts/publish-tap.sh          publish the version in project.yml
#   scripts/publish-tap.sh --check  say whether the tap is current, change nothing
#
# Runs AFTER publish-release.sh. The version and checksum are taken from the DMG GitHub
# is actually serving, not from dist/: a cask that disagrees with the served bytes breaks
# `brew install` for everyone, and there's no Sparkle to correct it. (Same lesson as
# Crivo's tap, which sat two releases behind because publishing was a sentence, not a
# script.)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/homebrew/lidboot.rb"
TAP="${LIDBOOT_TAP:-$(brew --prefix 2>/dev/null)/Library/Taps/h3x4d3x4/homebrew-tap}"
MODE="${1:-publish}"

VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' "$ROOT/project.yml" | head -1)
[ -n "$VERSION" ] || { echo "✗ could not read MARKETING_VERSION from project.yml" >&2; exit 1; }
URL="https://github.com/h3x4d3x4/LidBoot/releases/download/v$VERSION/LidBoot-$VERSION.dmg"

[ -d "$TAP/.git" ] || { echo "✗ no tap checkout at $TAP — brew tap h3x4d3x4/tap" >&2; exit 1; }

echo "▶ lidboot $VERSION"
echo "▶ Hashing what GitHub is actually serving…"
if ! SHA=$(curl -fsSL "$URL" | shasum -a 256 | cut -d' ' -f1); then
  echo "✗ $URL is not being served — run publish-release.sh first" >&2; exit 1
fi
echo "  sha256 $SHA"

# Reset rather than pull: a stale local tap produces a commit that can't be pushed and a
# working copy that looks published and isn't.
echo "▶ Syncing the tap…"
git -C "$TAP" fetch -q origin
git -C "$TAP" checkout -q main
git -C "$TAP" reset -q --hard origin/main

sed -E -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
       -e "s/^  sha256 \".*\"$/  sha256 \"$SHA\"/" "$TEMPLATE" > "$TAP/Casks/lidboot.rb"

if git -C "$TAP" diff --quiet && [ -z "$(git -C "$TAP" status --porcelain Casks/lidboot.rb)" ]; then
  echo "✓ the tap already publishes $VERSION — nothing to do"; exit 0
fi

if [ "$MODE" = "--check" ]; then
  echo "✗ the tap is NOT current for $VERSION:"
  git -C "$TAP" --no-pager diff --stat; git -C "$TAP" status --short Casks/lidboot.rb
  git -C "$TAP" checkout -q -- . 2>/dev/null; git -C "$TAP" clean -fdq
  exit 1
fi

# fetch is the gate: it downloads the URL and checks the sha256 — the two things that
# break `brew install` for everyone. audit is best-effort because brew refuses to run it
# at all when the installed Command Line Tools trail the macOS major (it did here).
echo "▶ Fetching through the cask (URL + checksum)…"
brew fetch --cask h3x4d3x4/tap/lidboot >/dev/null 2>&1 || { echo "✗ brew fetch failed — tap left modified, not pushed" >&2; exit 1; }
echo "▶ Auditing (best-effort)…"
brew audit --cask --strict h3x4d3x4/tap/lidboot >/dev/null 2>&1 || echo "  ! audit did not pass or could not run — review Casks/lidboot.rb by eye"

git -C "$TAP" add Casks/lidboot.rb
git -C "$TAP" commit -q -m "lidboot $VERSION"
git -C "$TAP" push -q origin main
echo "✅ Tap publishes lidboot $VERSION"
echo "   brew tap h3x4d3x4/tap && brew trust --cask h3x4d3x4/tap/lidboot && brew install --cask lidboot"
