import Charts
import SwiftUI
import TrainingKit

struct LoadChart: View {
    let points: [LoadPoint]
    var compact = false

    var body: some View {
        Chart {
            ForEach(points, id: \.day) { point in
                AreaMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Fitness", point.fitness)
                )
                .foregroundStyle(Palette.fitness.opacity(0.09))
            }
            ForEach(points, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Fatigue", point.fatigue),
                    series: .value("Metric", "fatigue")
                )
                .foregroundStyle(Palette.fatigue.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: compact ? 1.2 : 1.6, lineJoin: .round))
            }
            ForEach(points, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Fitness", point.fitness),
                    series: .value("Metric", "fitness")
                )
                .foregroundStyle(Palette.fitness)
                .lineStyle(StrokeStyle(lineWidth: compact ? 2 : 2.6, lineCap: .round, lineJoin: .round))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            if !compact {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day(.twoDigits).month(.twoDigits))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .chartYAxis {
            if !compact {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                        .foregroundStyle(Palette.fitness.opacity(0.18))
                    AxisValueLabel()
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

struct FormBarsChart: View {
    let points: [LoadPoint]

    var body: some View {
        Chart {
            RuleMark(y: .value("Form", 0))
                .foregroundStyle(Color.white.opacity(0.12))
            ForEach(points, id: \.day) { point in
                BarMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Form", point.form)
                )
                .foregroundStyle(Palette.form.opacity(0.8))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

struct ChartLegendItem: View {
    let title: LocalizedStringKey
    let color: Color
    var bar = false

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: bar ? 8 : 12, height: bar ? 8 : 3)
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.text.opacity(0.85))
        }
    }
}

struct VolumeBars: View {
    let weeks: [Double]

    var body: some View {
        let peak = weeks.max() ?? 0
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index == weeks.count - 1 ? Palette.fitness : Palette.fitness.opacity(0.32))
                    .frame(height: peak > 0 ? max(4, 56 * value / peak) : 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
