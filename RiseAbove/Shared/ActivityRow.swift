import SwiftUI
import TrainingKit

struct ActivityRow: View {
    enum Detail {
        case stress(Double)
        case pace
    }

    let activity: Activity
    let detail: Detail
    var showsDiscipline = true

    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                summary
                Spacer(minLength: 8)
                numbers(alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                summary
                numbers(alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var title: String {
        activity.title.isEmpty ? String(localized: activity.discipline.title) : activity.title
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.text)
            Group {
                if showsDiscipline {
                    Text("\(Text(activity.discipline.title)) · \(Text(activity.start, format: .dateTime.day().month(.wide).hour().minute()))")
                } else {
                    Text(activity.start, format: .dateTime.day().month(.wide).hour().minute())
                }
            }
            .font(.caption)
            .foregroundStyle(Palette.muted)
        }
    }

    private func numbers(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            if let distance = activity.distance, distance > 0 {
                Text(Formatting.distance(distance, discipline: activity.discipline, units: units))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Palette.text)
            }
            Group {
                switch detail {
                case .stress(let stress):
                    Text("\(stress.displayRounded) TSS")
                case .pace:
                    if let distance = activity.distance,
                       let pace = Formatting.pace(distance: distance, duration: activity.duration, discipline: activity.discipline, units: units) {
                        Text(pace)
                    } else {
                        Text(Duration.seconds(activity.duration), format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                    }
                }
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.muted)
        }
    }
}
