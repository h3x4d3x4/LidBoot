import AppKit
import CoreGraphics
import SwiftUI

// LidBoot icon, concept 2: "the opening lid".
//
// Side profile of a MacBook caught mid-open — a base bar and a lid bar hinged
// at one point, forming a wedge. It's the app's literal subject (the lid, and
// what happens when it opens) and collapses into a clean chevron-like mark at
// menu-bar sizes. A small warm dot sits in the opening: the power light — the
// thing this app decides whether to switch on.
//
// Variants:
//   A  brand gradient background, white glyph          (continuity)
//   B  deep-ink background, gradient glyph + warm dot  (dark, premium)
//   C  paper background, gradient glyph + warm dot     (light, minimal)

let args = CommandLine.arguments
let variant = args.count > 1 ? args[1] : "preview"
let outDir = args.count > 2 ? args[2] : "."

// Brand colours — Palette.lid / Palette.power from SharedViews.swift.
let blue   = CGColor(red: 0.36, green: 0.55, blue: 1.00, alpha: 1)
let purple = CGColor(red: 0.55, green: 0.40, blue: 1.00, alpha: 1)
let ember  = CGColor(red: 1.00, green: 0.62, blue: 0.28, alpha: 1)

func drawIcon(size: CGFloat, variant: String) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    // Apple's icon grid: 824/1024 body, continuous corners (measured off
    // Finder/System Settings — identical inset).
    let inset = size * 0.0977
    let body = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: inset, dy: inset)
    let radius = body.width * 0.2237
    let squircle = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: body).cgPath

    // Contact shadow, matching system icons.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.028,
                  color: CGColor(gray: 0, alpha: 0.28))
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // ── Background ──────────────────────────────────────────────────────────
    let space = CGColorSpaceCreateDeviceRGB()
    switch variant {
    case "A":
        let g = CGGradient(colorsSpace: space, colors: [blue, purple] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: body.minX, y: body.maxY),
                               end: CGPoint(x: body.maxX, y: body.minY), options: [])
    case "B":
        // Deep ink with a faint cool cast — dark, not black, so the shadow and
        // the Dock's dark mode both still separate from it.
        let top = CGColor(red: 0.13, green: 0.13, blue: 0.18, alpha: 1)
        let bottom = CGColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1)
        let g = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: body.midX, y: body.maxY),
                               end: CGPoint(x: body.midX, y: body.minY), options: [])
    default: // C
        let top = CGColor(red: 0.985, green: 0.985, blue: 0.995, alpha: 1)
        let bottom = CGColor(red: 0.92, green: 0.92, blue: 0.955, alpha: 1)
        let g = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: body.midX, y: body.maxY),
                               end: CGPoint(x: body.midX, y: body.minY), options: [])
    }

    // Sheen on the gradient variant only (B and C stay matte).
    if variant == "A" {
        let sheen = CGGradient(colorsSpace: space,
                               colors: [CGColor(gray: 1, alpha: 0.26), CGColor(gray: 1, alpha: 0)] as CFArray,
                               locations: [0, 1])!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: body.midX, y: body.maxY),
                               end: CGPoint(x: body.midX, y: body.midY), options: [])
    }

    // ── The wedge: base + lid hinged at the left ───────────────────────────
    let w = body.width
    let t = w * 0.095                     // bar thickness
    let barLength = w * 0.56
    let hinge = CGPoint(x: body.minX + w * 0.225, y: body.minY + w * 0.315)
    let lidAngle: CGFloat = 46 * .pi / 180

    func barPath(angle: CGFloat) -> CGPath {
        // A rounded bar from the hinge outward at `angle`, caps included.
        let rect = CGRect(x: 0, y: -t / 2, width: barLength, height: t)
        let p = RoundedRectangle(cornerRadius: t / 2, style: .continuous).path(in: rect).cgPath
        var transform = CGAffineTransform(translationX: hinge.x, y: hinge.y).rotated(by: angle)
        return p.copy(using: &transform) ?? p
    }

    let base = barPath(angle: 0)
    let lid = barPath(angle: lidAngle)

    let glyphIsWhite = (variant == "A")
    if glyphIsWhite {
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.addPath(base); ctx.fillPath()
        ctx.addPath(lid); ctx.fillPath()
    } else {
        // Gradient runs along the glyph: blue at the base tip, purple at the
        // lid tip, so the hinge is where the two mix — the pivot carries the
        // blend, which is the identity in one detail.
        for path in [base, lid] {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            let g = CGGradient(colorsSpace: space, colors: [blue, purple] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(
                g,
                start: CGPoint(x: hinge.x + barLength, y: hinge.y - t),
                end: CGPoint(x: hinge.x + cos(lidAngle) * barLength, y: hinge.y + sin(lidAngle) * barLength + t),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        }
        // Soft glow so the mark sits in the dark rather than floating on it.
        if variant == "B" {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: w * 0.10, color: CGColor(red: 0.45, green: 0.47, blue: 1.0, alpha: 0.55))
            ctx.setFillColor(CGColor(red: 0.45, green: 0.47, blue: 1.0, alpha: 0.10))
            ctx.addPath(base); ctx.fillPath()
            ctx.addPath(lid); ctx.fillPath()
            ctx.restoreGState()
        }
    }

    // ── The power light: one warm dot in the wedge opening ─────────────────
    if variant != "A" {
        let bisector = lidAngle / 2
        let dotDistance = barLength * 0.72
        let dotCenter = CGPoint(x: hinge.x + cos(bisector) * dotDistance,
                                y: hinge.y + sin(bisector) * dotDistance)
        let dotRadius = t * 0.42
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: dotRadius * 2.2, color: ember)
        ctx.setFillColor(ember)
        ctx.fillEllipse(in: CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                                   width: dotRadius * 2, height: dotRadius * 2))
        ctx.restoreGState()
    }

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

if variant == "preview" {
    // Comparison sheet: A/B/C at 220px, each with its 32px render beside it —
    // the small size is the one that kills icon concepts.
    let cell = 220, small = 32, pad = 24, label = 0
    let W = pad + (cell + pad + small + pad * 2) * 3
    let H = cell + pad * 2 + label
    let sheet = NSImage(size: NSSize(width: W, height: H))
    sheet.lockFocus()
    NSColor(calibratedWhite: 0.24, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()
    for (i, v) in ["A", "B", "C"].enumerated() {
        let x = pad + i * (cell + pad + small + pad * 2)
        drawIcon(size: CGFloat(cell), variant: v)
            .draw(in: NSRect(x: x, y: pad, width: cell, height: cell))
        drawIcon(size: CGFloat(small), variant: v)
            .draw(in: NSRect(x: x + cell + pad, y: pad + (cell - small) / 2, width: small, height: small))
    }
    sheet.unlockFocus()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    sheet.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outDir + "/concepts.png"))
    print("wrote concepts.png (A: gradient+white, B: ink+gradient, C: paper+gradient — each with its 32px render)")
} else {
    let variants: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
    for (pt, scale) in variants {
        let pixels = pt * scale
        let image = drawIcon(size: CGFloat(pixels), variant: variant)
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        try! png(image, pixels: pixels).write(to: URL(fileURLWithPath: outDir + "/" + name))
    }
    print("wrote full icon set, variant \(variant)")
}
