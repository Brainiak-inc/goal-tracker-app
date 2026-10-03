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

enum TextSizeController {
    private static let categories: [UIContentSizeCategory] = [
        .extraSmall,
        .small,
        .medium,
        .large,
        .extraLarge,
        .extraExtraLarge,
        .extraExtraExtraLarge,
        .accessibilityMedium,
        .accessibilityLarge,
        .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge
    ]

    static func apply(_ size: TextSize) {
        let system = UIApplication.shared.preferredContentSizeCategory
        let current = categories.firstIndex(of: system) ?? categories.firstIndex(of: .large) ?? 0
        let target = categories[min(max(current + size.step, 0), categories.count - 1)]
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            if size == .standard {
                scene.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            } else {
                scene.traitOverrides.preferredContentSizeCategory = target
            }
        }
    }
}

struct TextSizePicker: View {
    @Binding var size: TextSize

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextSize.allCases) { option in
                let isActive = option == size
                Button {
                    size = option
                } label: {
                    Text(verbatim: "A")
                        .font(.system(size: option.sample, weight: .semibold))
                        .foregroundStyle(isActive ? Palette.fitness : Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white.opacity(isActive ? 0.1 : 0.05), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(isActive ? Palette.fitness.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.title))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: size)
    }
}
