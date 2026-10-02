import AppKit
import CoreGraphics

let points: CGFloat = 320
let units: CGFloat = 1024
let rows: [(CGFloat, CGColor)] = [
    (754, CGColor(srgbRed: 0xFF / 255, green: 0xB0 / 255, blue: 0x20 / 255, alpha: 1)),
    (604, CGColor(srgbRed: 0x38 / 255, green: 0xBD / 255, blue: 0xF8 / 255, alpha: 1)),
    (454, CGColor(srgbRed: 0x2E / 255, green: 0xE9 / 255, blue: 0xFF / 255, alpha: 1))
]

func render(scale: CGFloat, to url: URL) {
    let size = Int(points * scale)
    let factor = CGFloat(size) / units
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
    for (base, color) in rows {
        context.saveGState()
        context.setShadow(offset: .zero, blur: 16 * scale, color: color.copy(alpha: 0.8))
        context.setStrokeColor(color)
        context.setLineWidth(70 * factor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 272 * factor, y: base * factor))
        context.addLine(to: CGPoint(x: 512 * factor, y: (base - 190) * factor))
        context.addLine(to: CGPoint(x: 752 * factor, y: base * factor))
        context.strokePath()
        context.restoreGState()
    }
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
render(scale: 2, to: folder.appendingPathComponent("LaunchMark@2x.png"))
render(scale: 3, to: folder.appendingPathComponent("LaunchMark@3x.png"))
