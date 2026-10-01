import AppKit
import CoreGraphics

let size = 1024
let cyan = CGColor(srgbRed: 0x2E / 255, green: 0xE9 / 255, blue: 0xFF / 255, alpha: 1)
let blue = CGColor(srgbRed: 0x38 / 255, green: 0xBD / 255, blue: 0xF8 / 255, alpha: 1)
let amber = CGColor(srgbRed: 0xFF / 255, green: 0xB0 / 255, blue: 0x20 / 255, alpha: 1)
let background = CGColor(srgbRed: 0x05 / 255, green: 0x07 / 255, blue: 0x0B / 255, alpha: 1)

func render(_ name: String, rounded: Bool, draw: (CGContext) -> Void) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: rounded ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
    if rounded {
        let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerWidth: 230, cornerHeight: 230, transform: nil)
        context.addPath(path)
        context.clip()
    }
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let glow = CGGradient(colorsSpace: space, colors: [cyan.copy(alpha: 0.16)!, cyan.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0, endCenter: CGPoint(x: 512, y: 560), endRadius: 560, options: [])

    context.setStrokeColor(cyan.copy(alpha: 0.06)!)
    context.setLineWidth(2)
    for offset in stride(from: 64, to: size, by: 64) {
        context.move(to: CGPoint(x: offset, y: 0))
        context.addLine(to: CGPoint(x: offset, y: size))
        context.move(to: CGPoint(x: 0, y: offset))
        context.addLine(to: CGPoint(x: size, y: offset))
    }
    context.strokePath()

    draw(context)

    let image = context.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name))
}

func brackets(_ context: CGContext, inset: CGFloat, length: CGFloat, radius: CGFloat, width: CGFloat) {
    let low = inset
    let high = CGFloat(size) - inset
    context.setStrokeColor(cyan)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: low, y: high - length))
    context.addArc(tangent1End: CGPoint(x: low, y: high), tangent2End: CGPoint(x: low + length, y: high), radius: radius)
    context.addLine(to: CGPoint(x: low + length, y: high))
    context.move(to: CGPoint(x: high, y: low + length))
    context.addArc(tangent1End: CGPoint(x: high, y: low), tangent2End: CGPoint(x: high - length, y: low), radius: radius)
    context.addLine(to: CGPoint(x: high - length, y: low))
    context.strokePath()
}

func withGlow(_ context: CGContext, _ color: CGColor, blur: CGFloat = 36, _ body: () -> Void) {
    context.saveGState()
    context.setShadow(offset: .zero, blur: blur, color: color.copy(alpha: 0.85))
    body()
    context.restoreGState()
}

func rising(_ context: CGContext) {
    brackets(context, inset: 140, length: 170, radius: 96, width: 22)
    let points: [CGPoint] = [(0.20, 0.33), (0.34, 0.39), (0.45, 0.35), (0.57, 0.52), (0.67, 0.48), (0.80, 0.70)]
        .map { CGPoint(x: $0.0 * Double(size), y: $0.1 * Double(size)) }
    withGlow(context, cyan) {
        context.setStrokeColor(cyan)
        context.setLineWidth(54)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addLines(between: points)
        context.strokePath()
    }
    let end = points.last!
    context.setFillColor(CGColor(srgbRed: 0.9, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: CGRect(x: end.x - 46, y: end.y - 46, width: 92, height: 92))
}

func chevrons(_ context: CGContext) {
    let rows: [(CGFloat, CGColor)] = [(270, amber), (420, blue), (570, cyan)]
    for (y, color) in rows {
        withGlow(context, color, blur: 28) {
            context.setStrokeColor(color)
            context.setLineWidth(70)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: 512 - 240, y: y))
            context.addLine(to: CGPoint(x: 512, y: y + 190))
            context.addLine(to: CGPoint(x: 512 + 240, y: y))
            context.strokePath()
        }
    }
}

func ring(_ context: CGContext) {
    let center = CGPoint(x: 512, y: 512)
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08))
    context.setLineWidth(76)
    context.addEllipse(in: CGRect(x: center.x - 300, y: center.y - 300, width: 600, height: 600))
    context.strokePath()
    withGlow(context, cyan) {
        context.setStrokeColor(cyan)
        context.setLineWidth(76)
        context.setLineCap(.round)
        context.addArc(center: center, radius: 300, startAngle: .pi / 2, endAngle: .pi / 2 - 1.5 * .pi, clockwise: true)
        context.strokePath()
    }
    withGlow(context, amber, blur: 24) {
        context.setStrokeColor(amber)
        context.setLineWidth(58)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 512 - 130, y: 450))
        context.addLine(to: CGPoint(x: 512, y: 590))
        context.addLine(to: CGPoint(x: 512 + 130, y: 450))
        context.strokePath()
    }
}

for (name, draw) in [("A-rising", rising), ("B-chevrons", chevrons), ("C-ring", ring)] as [(String, (CGContext) -> Void)] {
    render("\(name).png", rounded: false, draw: draw)
    render("\(name)-preview.png", rounded: true, draw: draw)
}
