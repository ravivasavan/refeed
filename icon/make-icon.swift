// Draws Refeed's app icon: four rounded viewfinder corners, a portrait frame,
// in VasavanOS colours (Color 1 lime on Color 2 teal), inside the standard
// macOS icon container. Writes icon/AppIcon.iconset, which build.sh turns
// into AppIcon.icns.
//
//   xcrun swift icon/make-icon.swift

import AppKit

let lime = NSColor(srgbRed: 0xab / 255, green: 0xff / 255, blue: 0x5a / 255, alpha: 1) // --color-1
let teal = NSColor(srgbRed: 0x08 / 255, green: 0x5e / 255, blue: 0x55 / 255, alpha: 1) // --color-2

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024 // design on a 1024 grid

    // Container: Apple's 824pt rounded square, centred, with a soft drop shadow.
    let box = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let container = NSBezierPath(roundedRect: box, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowBlurRadius = 20 * s
    shadow.set()
    teal.setFill()
    container.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Four corners of a portrait frame, rounded like a camera's face box.
    let w: CGFloat = 400 * s, h: CGFloat = 500 * s
    let frame = NSRect(x: (CGFloat(px) - w) / 2, y: (CGFloat(px) - h) / 2, width: w, height: h)
    let arm: CGFloat = 120 * s, r: CGFloat = 70 * s
    let corners = NSBezierPath()
    for (cx, cy, dx, dy) in [
        (frame.minX, frame.maxY, 1.0, -1.0), (frame.maxX, frame.maxY, -1.0, -1.0),
        (frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0),
    ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
        corners.move(to: NSPoint(x: cx, y: cy + dy * arm))
        corners.appendArc(from: NSPoint(x: cx, y: cy), to: NSPoint(x: cx + dx * arm, y: cy), radius: r)
        corners.line(to: NSPoint(x: cx + dx * arm, y: cy))
    }
    corners.lineWidth = 48 * s
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round
    lime.setStroke()
    corners.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon/AppIcon.iconset")
try? FileManager.default.removeItem(at: dir)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
