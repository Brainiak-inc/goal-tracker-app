import SwiftUI

enum TextSize: String, CaseIterable, Identifiable {
    case smaller
    case standard
    case larger
    case largest

    static let storageKey = "textSize"

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .smaller: "Smaller"
        case .standard: "Standard"
        case .larger: "Larger"
        case .largest: "Largest"
        }
    }

    var step: Int {
        switch self {
        case .smaller: -1
        case .standard: 0
        case .larger: 1
        case .largest: 2
        }
    }

    var sample: CGFloat {
        switch self {
        case .smaller: 13
        case .standard: 17
        case .larger: 21
        case .largest: 25
        }
    }
}

struct TextSizeAdjustment: ViewModifier {
    @Environment(\.dynamicTypeSize) private var system
    @AppStorage(TextSize.storageKey) private var size: TextSize = .standard

    func body(content: Content) -> some View {
        content.dynamicTypeSize(adjusted)
    }

    private var adjusted: DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        let current = sizes.firstIndex(of: system) ?? sizes.firstIndex(of: .large) ?? 0
        return sizes[min(max(current + size.step, 0), sizes.count - 1)]
    }
}

struct TextSizePicker: View {
    @AppStorage(TextSize.storageKey) private var size: TextSize = .standard

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextSize.allCases) { option in
                Button {
                    withAnimation(.snappy) {
                        size = option
                    }
                } label: {
                    Text(verbatim: "A")
                        .font(.system(size: option.sample, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.consoleChip(isActive: option == size))
                .accessibilityLabel(Text(option.title))
                .accessibilityAddTraits(option == size ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: size)
    }
}
