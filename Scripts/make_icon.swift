// make_icon.swift -- draw the application's keyboard icon and encode an ICNS file.
// Created by LT Sean Egan, PhD 2026-10-15
// Modified: SDE 2026-10-18 draw at exact pixel sizes on Retina displays.
import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make_icon.swift <output.icns>\n", stderr)
    exit(EXIT_FAILURE)
}

func bigEndian(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}

var chunks = Data()
for (type, size) in [("icp4", 16), ("icp5", 32), ("icp6", 64),
                     ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904),
                                  xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.46, blue: 0.91, alpha: 1),
               ending: NSColor(calibratedRed: 0.14, green: 0.22, blue: 0.60, alpha: 1))!
        .draw(in: background, angle: -90)
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: NSRect(x: 168, y: 310, width: 688, height: 404),
                 xRadius: 54, yRadius: 54).fill()
    NSColor(calibratedRed: 0.17, green: 0.33, blue: 0.67, alpha: 1).setFill()
    for row in 0..<3 {
        for column in 0..<8 {
            NSBezierPath(roundedRect: NSRect(x: 214 + column * 76, y: 480 + row * 65,
                                             width: 55, height: 43),
                         xRadius: 10, yRadius: 10).fill()
        }
    }
    NSBezierPath(roundedRect: NSRect(x: 336, y: 381, width: 352, height: 54),
                 xRadius: 12, yRadius: 12).fill()
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    chunks.append(Data(type.utf8))
    chunks.append(bigEndian(UInt32(png.count + 8)))
    chunks.append(png)
}
var output = Data("icns".utf8)
output.append(bigEndian(UInt32(chunks.count + 8)))
output.append(chunks)
try output.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
