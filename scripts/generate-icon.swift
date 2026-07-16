import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("Usage: generate-icon.swift <iconset-directory> <preview-png> <icns-output>\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: arguments[1])
let previewURL = URL(fileURLWithPath: arguments[2])
let icnsURL = URL(fileURLWithPath: arguments[3])
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try fileManager.createDirectory(at: icnsURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: Int) -> NSImage {
    let imageSize = NSSize(width: size, height: size)
    let image = NSImage(size: imageSize)
    image.lockFocus()

    let scale = CGFloat(size) / 1024
    func r(_ value: CGFloat) -> CGFloat { value * scale }

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: imageSize).fill()

    let canvas = NSRect(x: r(48), y: r(48), width: r(928), height: r(928))
    let background = NSBezierPath(roundedRect: canvas, xRadius: r(220), yRadius: r(220))
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.33, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.65, blue: 0.72, alpha: 1)
    ])
    gradient?.draw(in: background, angle: 135)

    NSColor(calibratedWhite: 1, alpha: 0.18).setStroke()
    let border = NSBezierPath(roundedRect: canvas.insetBy(dx: r(20), dy: r(20)), xRadius: r(200), yRadius: r(200))
    border.lineWidth = r(12)
    border.stroke()

    let pageShadow = NSBezierPath(roundedRect: NSRect(x: r(260), y: r(184), width: r(520), height: r(680)), xRadius: r(58), yRadius: r(58))
    NSColor(calibratedWhite: 0, alpha: 0.16).setFill()
    pageShadow.fill()

    let page = NSBezierPath(roundedRect: NSRect(x: r(238), y: r(210), width: r(520), height: r(680)), xRadius: r(58), yRadius: r(58))
    NSColor(calibratedRed: 0.96, green: 0.98, blue: 1, alpha: 1).setFill()
    page.fill()

    NSColor(calibratedRed: 0.84, green: 0.90, blue: 0.97, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: r(328), y: r(760), width: r(340), height: r(32)), xRadius: r(16), yRadius: r(16)).fill()
    NSBezierPath(roundedRect: NSRect(x: r(328), y: r(690), width: r(300), height: r(28)), xRadius: r(14), yRadius: r(14)).fill()
    NSBezierPath(roundedRect: NSRect(x: r(328), y: r(622), width: r(270), height: r(28)), xRadius: r(14), yRadius: r(14)).fill()

    let barColors = [
        NSColor(calibratedRed: 0.09, green: 0.40, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.64, blue: 0.33, alpha: 1),
        NSColor(calibratedRed: 0.90, green: 0.36, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.78, green: 0.18, blue: 0.52, alpha: 1)
    ]

    let bars: [(x: CGFloat, height: CGFloat)] = [
        (330, 120),
        (430, 206),
        (530, 164),
        (630, 270)
    ]

    for (index, bar) in bars.enumerated() {
        barColors[index].setFill()
        NSBezierPath(
            roundedRect: NSRect(x: r(bar.x), y: r(312), width: r(62), height: r(bar.height)),
            xRadius: r(24),
            yRadius: r(24)
        ).fill()
    }

    NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.25, alpha: 0.92).setFill()
    let bookmark = NSBezierPath()
    bookmark.move(to: NSPoint(x: r(236), y: r(812)))
    bookmark.line(to: NSPoint(x: r(236), y: r(590)))
    bookmark.line(to: NSPoint(x: r(306), y: r(644)))
    bookmark.line(to: NSPoint(x: r(376), y: r(590)))
    bookmark.line(to: NSPoint(x: r(376), y: r(812)))
    bookmark.close()
    bookmark.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) throws {
    guard let data = NSMutableData() as CFMutableData?,
          let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "StudyTrackerIcon", code: 1)
    }

    CGImageDestinationAddImage(destination, cgImage, [
        kCGImagePropertyPNGDictionary: [:]
    ] as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "StudyTrackerIcon", code: 2)
    }

    try (data as Data).write(to: url, options: [.atomic])
}

for iconSize in iconSizes {
    let image = drawIcon(size: iconSize.pixels)
    try writePNG(image, to: iconsetURL.appendingPathComponent(iconSize.name), pixels: iconSize.pixels)
}

try writePNG(drawIcon(size: 1024), to: previewURL, pixels: 1024)

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

func appendOSType(_ type: String, to data: inout Data) {
    data.append(type.data(using: .ascii)!)
}

let icnsEntries: [(type: String, fileName: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var chunks = Data()
for entry in icnsEntries {
    let pngData = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.fileName))
    appendOSType(entry.type, to: &chunks)
    appendUInt32(UInt32(pngData.count + 8), to: &chunks)
    chunks.append(pngData)
}

var icns = Data()
appendOSType("icns", to: &icns)
appendUInt32(UInt32(chunks.count + 8), to: &icns)
icns.append(chunks)
try icns.write(to: icnsURL, options: [.atomic])
