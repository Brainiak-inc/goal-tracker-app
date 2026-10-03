import SwiftUI

struct ConsoleSpinner: View {
    var size: CGFloat = 14
    var lineWidth: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9
            ZStack {
                Circle()
                    .stroke(Palette.fitness.opacity(0.16), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [Palette.fitness.opacity(0), Palette.fitness],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(252)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .shadow(color: Palette.fitness.opacity(0.7), radius: lineWidth * 1.5)
                    .rotationEffect(.degrees(reduceMotion ? 0 : turn * 360))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ConsoleProgressBar: View {
    let value: Double

    @State private var shown = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(Palette.fitness)
                    .frame(width: max(6, proxy.size.width * min(max(shown, 0), 1)))
                    .shadow(color: Palette.fitness.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 6)
        .fillProgress(to: value, shown: $shown)
    }
}
