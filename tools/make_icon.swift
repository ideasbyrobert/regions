import AppKit

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconsetURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent("Regions.iconset")
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func render(size: Int) -> Data?
{
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext
    else
    {
        image.unlockFocus()
        return nil
    }

    let inset = side * 0.055
    let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: side * 0.2237,
        cornerHeight: side * 0.2237,
        transform: nil
    )
    context.saveGState()
    context.addPath(path)
    context.clip()

    let colors = [
        NSColor(calibratedRed: 0.18, green: 0.42, blue: 1.00, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.65, alpha: 1.0).cgColor
    ] as CFArray

    if let space = CGColorSpace(name: CGColorSpace.sRGB),
       let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])
    {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: side),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }
    context.restoreGState()

    let config = NSImage.SymbolConfiguration(pointSize: side * 0.52, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let tinted = NSImage(size: symbol.size, flipped: false)
        {
            bounds in
            NSColor.white.set()
            bounds.fill()
            symbol.draw(in: bounds, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        let width = side * 0.52
        let height = width * (symbol.size.height / symbol.size.width)
        tinted.draw(
            in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height),
            from: .zero,
            operation: .sourceOver,
            fraction: 0.95
        )
    }

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else
    {
        return nil
    }
    return rep.representation(using: .png, properties: [:])
}

let variants: [(String, Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

for (name, size) in variants
{
    guard let data = render(size: size)
    else
    {
        continue
    }
    try? data.write(to: iconsetURL.appendingPathComponent("\(name).png"))
}

print(iconsetURL.path)
