import SwiftUI

struct SwipeSwitch<Value: Hashable>: ViewModifier {
    @Binding var selection: Value
    let values: [Value]
    @Binding var edge: Edge

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) * 1.4 else { return }
                        offset = dx * (canMove(towards: dx) ? 0.35 : 0.12)
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let isHorizontal = abs(dx) > abs(value.translation.height) * 1.4
                        let isFarEnough = abs(dx) > 60 || abs(value.predictedEndTranslation.width) > 180
                        withAnimation(.snappy) { offset = 0 }
                        guard isHorizontal, isFarEnough, canMove(towards: dx) else { return }
                        let target = values[index + (dx < 0 ? 1 : -1)]
                        switchSelection(to: target, selection: $selection, values: values, edge: $edge)
                    }
            )
            .sensoryFeedback(.selection, trigger: selection)
    }

    private var index: Int {
        values.firstIndex(of: selection) ?? 0
    }

    private func canMove(towards dx: CGFloat) -> Bool {
        dx < 0 ? index < values.count - 1 : index > 0
    }
}

extension View {
    func swipeToSwitch<Value: Hashable>(_ selection: Binding<Value>, among values: [Value], edge: Binding<Edge>) -> some View {
        modifier(SwipeSwitch(selection: selection, values: values, edge: edge))
    }

    func switchTransition(edge: Edge) -> some View {
        transition(.push(from: edge))
    }
}

func switchSelection<Value: Hashable>(to target: Value, selection: Binding<Value>, values: [Value], edge: Binding<Edge>) {
    let from = values.firstIndex(of: selection.wrappedValue) ?? 0
    let to = values.firstIndex(of: target) ?? 0
    guard from != to else { return }
    edge.wrappedValue = to > from ? .trailing : .leading
    DispatchQueue.main.async {
        withAnimation(.snappy) {
            selection.wrappedValue = target
        }
    }
}

func animatedSwitch<Value: Hashable>(_ selection: Binding<Value>, among values: [Value], edge: Binding<Edge>) -> Binding<Value> {
    Binding {
        selection.wrappedValue
    } set: { target in
        switchSelection(to: target, selection: selection, values: values, edge: edge)
    }
}
