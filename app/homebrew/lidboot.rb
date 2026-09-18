# Homebrew cask for LidBoot — published to h3x4d3x4/homebrew-tap by scripts/publish-tap.sh,
# which rewrites version and sha256 from the DMG GitHub is actually serving. Don't edit
# those two lines by hand: a checksum that disagrees with the file breaks `brew install`
# for everyone at once, and unlike a bad DMG there's no Sparkle to correct it.
#
#   brew tap h3x4d3x4/tap
#   brew trust --cask h3x4d3x4/tap/lidboot     # Homebrew 7 gates third-party casks
#   brew install --cask lidboot
#
# auto_updates: the app updates itself through Sparkle, so without this Homebrew would
# report it outdated forever and offer to reinstall over a copy that already updated.
cask "lidboot" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/h3x4d3x4/LidBoot/releases/download/v#{version}/LidBoot-#{version}.dmg",
      verified: "github.com/h3x4d3x4/LidBoot/"
  name "LidBoot"
  desc "Stop your MacBook starting up when you open the lid or connect power"
  homepage "https://lidboot.hexadexa.io/"

  livecheck do
    url "https://raw.githubusercontent.com/h3x4d3x4/LidBoot/main/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  # BootPreference exists only on Apple silicon running macOS 15+; the app disables
  # itself elsewhere, so don't let Homebrew install it there in the first place.
  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "LidBoot.app"

  uninstall quit: "com.lidboot.LidBoot"

  # The firmware setting itself is deliberately NOT touched: zap removes the app's
  # preferences, not a value in NVRAM the user chose. Restore Default in the app does that.
  zap trash: [
    "~/Library/Preferences/com.lidboot.LidBoot.plist",
    "~/Library/Caches/com.lidboot.LidBoot",
    "~/Library/HTTPStorages/com.lidboot.LidBoot",
  ]
end
