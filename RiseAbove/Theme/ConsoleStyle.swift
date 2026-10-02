import SwiftUI

struct ConsoleBackground: View {
    var body: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: 0, through: size.width, by: 24) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: 24) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(Palette.fitness.opacity(0.035)), lineWidth: 1)
        }
        .background(Palette.background)
        .ignoresSafeArea()
    }
}

nonisolated struct CornerBrackets: Shape {
    var radius: CGFloat
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + length, y: rect.minY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - length, y: rect.maxY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        return path
    }
}

struct ConsoleCard: ViewModifier {
    var brackets = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: shape)
            .overlay {
                shape.strokeBorder(Palette.fitness.opacity(0.14), lineWidth: 1)
            }
            .overlay {
                if brackets {
                    CornerBrackets(radius: 20, length: 22)
                        .stroke(Palette.fitness, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
    }
}

extension View {
    func consoleCard(brackets: Bool = true) -> some View {
        modifier(ConsoleCard(brackets: brackets))
    }

    func consoleLabel() -> some View {
        font(.system(.caption2, design: .monospaced, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Palette.muted)
    }
}

struct ConsolePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.fitness)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Palette.fitness.opacity(0.7), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct ConsoleSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(.regular.interactive(), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct ConsoleChipButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isActive ? Palette.fitness : Palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay {
                if isActive {
                    Capsule().strokeBorder(Palette.fitness.opacity(0.6), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ConsolePrimaryButtonStyle {
    static var consolePrimary: ConsolePrimaryButtonStyle { ConsolePrimaryButtonStyle() }
}

extension ButtonStyle where Self == ConsoleSecondaryButtonStyle {
    static var consoleSecondary: ConsoleSecondaryButtonStyle { ConsoleSecondaryButtonStyle() }
}

extension ButtonStyle where Self == ConsoleChipButtonStyle {
    static func consoleChip(isActive: Bool) -> ConsoleChipButtonStyle { ConsoleChipButtonStyle(isActive: isActive) }
}
