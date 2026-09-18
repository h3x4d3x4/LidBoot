import AppKit
import LidBootCore

/// The status item glyph, composed at runtime so it can say which of the two
/// switches is off — the two SF Symbols alone (`laptopcomputer` and its
/// `.slash`) could only say "something is".
///
///   both start up      laptopcomputer
///   lid won't          laptopcomputer.slash
///   power won't        laptopcomputer      + bolt.slash badge
///   neither will       laptopcomputer.slash + bolt.slash badge
///   unsupported/refusing   laptopcomputer.trianglebadge.exclamationmark
///
/// The bolt is the same glyph the power row uses inside the app, so the badge
/// reads as "that row" rather than as a new symbol to learn. Template images,
/// so the menu bar tints them like any system item.
@MainActor
enum MenuBarIcon {
    static func image(for behavior: BootBehavior?, refusing: Bool) -> NSImage {
        guard let behavior, !refusing else {
            return symbol("laptopcomputer.trianglebadge.exclamationmark")
        }
        let base = symbol(behavior.startsOnLidOpen ? "laptopcomputer" : "laptopcomputer.slash")
        guard !behavior.startsOnPowerConnect else { return base }
        return badged(base, with: "bolt.slash.fill")
    }

    private static func symbol(_ name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }

    /// Bottom-right badge with a knockout ring, the way SF's own `.badge.*`
    /// variants are drawn, so it stays legible against the base glyph.
    private static func badged(_ base: NSImage, with badgeName: String) -> NSImage {
        let badge = NSImage(systemSymbolName: badgeName, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 9, weight: .heavy))!
        let size = base.size
        let result = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            let badgeSize = badge.size
            let origin = CGPoint(x: rect.maxX - badgeSize.width + 2, y: rect.minY - 1)
            let badgeRect = CGRect(origin: origin, size: badgeSize)
            // Knock out the base behind the badge.
            NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
            NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.25, dy: -1.25)).fill()
            NSGraphicsContext.current?.cgContext.setBlendMode(.normal)
            badge.draw(in: badgeRect)
            return true
        }
        result.isTemplate = true
        return result
    }
}
