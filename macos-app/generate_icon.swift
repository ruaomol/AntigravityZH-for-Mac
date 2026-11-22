import AppKit
import CoreGraphics
import Foundation

// Resamples the user-provided macOS icon PNG into a full Retina .iconset
// with tight bounding-box centering and standard macOS Dock visual proportions (~82% grid).
guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: swift generate_icon.swift <source.png> <output.iconset>\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let srcData = try? Data(contentsOf: sourceURL),
      let srcRep = NSBitmapImageRep(data: srcData),
      let srcCG = srcRep.cgImage else {
    fputs("Failed to load source icon PNG at \(sourceURL.path)\n", stderr)
    exit(1)
}

// Detect visible non-transparent content bounding box so the squircle sits dead-center
let w = srcRep.pixelsWide
let h = srcRep.pixelsHigh
var minX = w, maxX = 0, minY = h, maxY = 0
for y in stride(from: 0, to: h, by: 2) {
    for x in stride(from: 0, to: w, by: 2) {
        if let c = srcRep.colorAt(x: x, y: y), c.alphaComponent > 0.06 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}

let cropRect: CGRect
if maxX > minX && maxY > minY {
    let cw = CGFloat(maxX - minX + 1)
    let ch = CGFloat(maxY - minY + 1)
    let side = max(cw, ch)
    let cx = CGFloat(minX) + cw * 0.5
    let cy = CGFloat(minY) + ch * 0.5
    cropRect = CGRect(
        x: max(0, cx - side * 0.5),
        y: max(0, cy - side * 0.5),
        width: min(CGFloat(w), side),
        height: min(CGFloat(h), side)
    )
} else {
    cropRect = CGRect(x: 0, y: 0, width: w, height: h)
}

let croppedCG = srcCG.cropping(to: cropRect) ?? srcCG

func saveScaledPNG(from cgImage: CGImage, pixelSize: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGen", code: 1)
    }

    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = nsCtx
    if let ctx = nsCtx?.cgContext {
        ctx.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        ctx.interpolationQuality = .high
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        // Standard macOS Big Sur / Sequoia icon padding (~82.5% visual footprint)
        let s = CGFloat(pixelSize)
        let inset = s * 0.088
        let target = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        ctx.draw(cgImage, in: target)
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2)
    }
    try png.write(to: url)
}

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, px) in specs {
    try saveScaledPNG(from: croppedCG, pixelSize: px, to: iconsetURL.appendingPathComponent(filename))
}
print("Generated iconset from \(sourceURL.lastPathComponent) at \(iconsetURL.path)")
