// Generates the DMG installer background (assets/macos/dmg-background.png).
//
// Renders at exactly the Finder window size (600x400). Finder draws the
// .DS_Store background image at its native pixel dimensions with no scaling,
// so the image must match the window size 1:1 — a @2x image would only show
// its top-left quadrant. Layout must match the icon positions used by
// scripts/release/build_desktop.dart (--icon 150 210, --app-drop-link 450 210,
// both measured from the top-left in points).
//
// Usage: swift scripts/macos/generate_dmg_background.swift <output.png>

import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("usage: generate_dmg_background.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let outputPath = arguments[1]

let logicalWidth = 600.0
let logicalHeight = 400.0
let width = Int(logicalWidth)
let height = Int(logicalHeight)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("failed to allocate bitmap") }

NSGraphicsContext.saveGraphicsState()
guard let nsContext = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("failed to create graphics context") }
NSGraphicsContext.current = nsContext
let ctx = nsContext.cgContext

func color(_ hex: Int, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xff) / 255.0,
        green: CGFloat((hex >> 8) & 0xff) / 255.0,
        blue: CGFloat(hex & 0xff) / 255.0,
        alpha: alpha
    )
}

// Dark vertical gradient matching the app's dark theme.
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0x26282d), color(0x181a1e)] as CFArray,
    locations: [0, 1]
) else { fatalError("failed to create gradient") }
// cg origin is bottom-left: start at the top so the lighter stop is on top.
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: logicalHeight),
    end: CGPoint(x: 0, y: 0),
    options: []
)

func drawCenteredText(_ text: String, topY: CGFloat, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
    }()
    let textSize = (text as NSString).size(withAttributes: attributes)
    let rect = CGRect(x: 0, y: logicalHeight - topY - textSize.height, width: logicalWidth, height: textSize.height)
    (text as NSString).draw(in: rect, withAttributes: attributes)
}

drawCenteredText("FlyNarwhal", topY: 52, fontSize: 30, weight: .semibold, color: NSColor(white: 0.95, alpha: 1))
drawCenteredText(
    "Drag FlyNarwhal to the Applications folder to install",
    topY: 102,
    fontSize: 13,
    weight: .regular,
    color: NSColor(white: 1, alpha: 0.55)
)

// Arrow spanning the gap between the app icon (center 150,210, right edge 198)
// and the Applications link (center 450,210, left edge 402).
let arrowY = logicalHeight - 210
let arrowColor = color(0x8aa0d8, alpha: 0.5)
ctx.setStrokeColor(arrowColor)
ctx.setFillColor(arrowColor)
ctx.setLineWidth(2.5)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 225, y: arrowY))
ctx.addLine(to: CGPoint(x: 368, y: arrowY))
ctx.strokePath()
ctx.move(to: CGPoint(x: 368, y: arrowY + 8))
ctx.addLine(to: CGPoint(x: 385, y: arrowY))
ctx.addLine(to: CGPoint(x: 368, y: arrowY - 8))
ctx.closePath()
ctx.fillPath()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encoding failed") }
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fatalError("failed to write \(outputPath): \(error)")
}
print("wrote \(outputPath) (\(width)x\(height))")
