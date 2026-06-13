#!/usr/bin/env swift
import AppKit

// Generates the 1024×1024 app icon: a teal gradient with a white pin holding a
// fork.knife glyph, plus a small check badge. Run: swift Tools/make_icon.swift <out.png>

let size = 1024.0
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Background gradient (teal → deep teal).
let colors = [
    NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.60, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.02, green: 0.36, blue: 0.42, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Render an SF Symbol tinted to a flat color, drawn into `rect` (aspect-fit).
func drawSymbol(_ name: String, color: NSColor, height: CGFloat, center: CGPoint) {
    let cfg = NSImage.SymbolConfiguration(pointSize: height, weight: .semibold)
    guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return }
    let aspect = sym.size.width / max(sym.size.height, 1)
    let drawSize = NSSize(width: height * aspect, height: height)
    let tinted = NSImage(size: drawSize)
    tinted.lockFocus()
    color.set()
    let r = NSRect(origin: .zero, size: drawSize)
    sym.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(in: NSRect(x: center.x - drawSize.width/2, y: center.y - drawSize.height/2,
                           width: drawSize.width, height: drawSize.height))
}

// Big white fork & knife, centered slightly high.
drawSymbol("fork.knife", color: .white, height: size * 0.42,
           center: CGPoint(x: size * 0.5, y: size * 0.55))

// Green check-seal badge, bottom-right, with a white ring for separation.
let badgeCenter = CGPoint(x: size * 0.66, y: size * 0.30)
drawSymbol("seal.fill", color: .white, height: size * 0.32, center: badgeCenter)
drawSymbol("checkmark.seal.fill",
           color: NSColor(calibratedRed: 0.18, green: 0.76, blue: 0.34, alpha: 1),
           height: size * 0.28, center: badgeCenter)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render\n".utf8)); exit(1)
}
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
