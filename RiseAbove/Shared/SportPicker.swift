import SwiftUI
import TrainingKit

struct SportPicker: View {
    @Binding var profile: SportProfile
    var allowsEmpty = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Sport.allCases, id: \.self) { sport in
                SportRow(
                    sport: sport,
                    isSelected: profile.isSelected(sport),
                    isIncluded: profile.isIncludedInTriathlon(sport)
                ) {
                    withAnimation(.snappy) {
                        profile.toggle(sport, allowsEmpty: allowsEmpty)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: profile)
    }
}

private struct SportRow: View {
    let sport: Sport
    let isSelected: Bool
    let isIncluded: Bool
    let action: () -> Void

    private var isOn: Bool { isSelected || isIncluded }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon
                    .frame(width: 44, height: 44)
                    .background(isOn ? Palette.fitness.opacity(0.08) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(sport.title)
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        if isIncluded {
                            Text("In triathlon")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.fitness)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay {
                                    Capsule().strokeBorder(Palette.fitness.opacity(0.45), lineWidth: 1)
                                }
                        }
                    }
                    Text(sport.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                check
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Palette.fitness.opacity(0.04) : Palette.surface, in: shape)
            .overlay {
                shape.strokeBorder(Palette.fitness.opacity(isSelected ? 0.75 : isIncluded ? 0.32 : 0.12), lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isIncluded ? Text("Included in triathlon") : Text(verbatim: ""))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    @ViewBuilder
    private var icon: some View {
        if sport == .triathlon {
            TriathlonMark()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: sport.disciplines[0].symbol)
                .font(.title3)
                .foregroundStyle(isOn ? Palette.fitness : Palette.text.opacity(0.8))
        }
    }

    private var check: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Palette.fitness : isIncluded ? Palette.fitness.opacity(0.18) : .clear)
            Circle()
                .strokeBorder(isOn ? Palette.fitness.opacity(isSelected ? 1 : 0.5) : Color.white.opacity(0.28), lineWidth: 1.5)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Palette.background : Palette.fitness)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

private struct TriathlonMark: View {
    var body: some View {
        Canvas { context, size in
            let colors = [Palette.fitness, Palette.form, Palette.fatigue]
            let scale = size.width / 24
            for (index, color) in colors.enumerated() {
                let y = (10 + CGFloat(index) * 4.5) * scale
                var path = Path()
                path.move(to: CGPoint(x: 5 * scale, y: y))
                path.addLine(to: CGPoint(x: 12 * scale, y: y - 5 * scale))
                path.addLine(to: CGPoint(x: 19 * scale, y: y))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
