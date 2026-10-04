// Renders Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // macOS icon grid: 824/1024 body with a soft shadow margin.
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset * 1.1, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1),
                        NSColor(red: 0.06, green: 0.20, blue: 0.62, alpha: 1)])!
        .draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: body.width * 0.46, weight: .regular)
        .applying(.init(paletteColors: [.white]))
    let symbol = NSImage(systemSymbolName: "earbuds", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let size = symbol.size
    symbol.draw(in: NSRect(x: body.midX - size.width / 2, y: body.midY - size.height / 2,
                           width: size.width, height: size.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! render(1024).write(to: URL(fileURLWithPath: "/tmp/AppIcon-preview.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
print("wrote Resources/AppIcon.icns")
