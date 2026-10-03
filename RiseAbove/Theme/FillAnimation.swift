import SwiftUI

extension Animation {
    static let fill = Animation.spring(duration: 0.9, bounce: 0.12)
}

struct FillProgress: ViewModifier {
    let target: Double
    var delay: Double = 0
    @Binding var shown: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onAppear {
                fill()
            }
            .onChange(of: target) {
                fill()
            }
            .onDisappear {
                shown = 0
            }
    }

    private func fill() {
        if reduceMotion {
            shown = target
        } else {
            withAnimation(.fill.delay(delay)) {
                shown = target
            }
        }
    }
}

struct CountingPercent: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: "\(Int(value.rounded()))%")
    }
}

extension View {
    func fillProgress(to target: Double, shown: Binding<Double>, delay: Double = 0) -> some View {
        modifier(FillProgress(target: target, delay: delay, shown: shown))
    }
}
