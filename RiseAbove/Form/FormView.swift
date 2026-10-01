import SwiftUI
import TrainingKit

struct FormView: View {
    enum Period: Int, CaseIterable, Identifiable {
        case sixWeeks = 42
        case threeMonths = 91
        case year = 365

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .sixWeeks: "6 weeks"
            case .threeMonths: "3 months"
            case .year: "Year"
            }
        }
    }

    @Environment(ActivityLibrary.self) private var library
    @State private var period: Period = .sixWeeks

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let fitness = library.fitness {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    chartCard
                    tiles(fitness)
                    if let trend = library.fitnessTrend {
                        Text(explanation(trend.delta))
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Import workouts to see how fitness, fatigue, and form change.")
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { ConsoleBackground() }
        .navigationTitle("Form")
    }

    private var points: [LoadPoint] {
        Array(library.series.suffix(period.rawValue))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
            LoadChart(points: points)
                .frame(height: 200)
            FormBarsChart(points: points)
                .frame(height: 64)
        }
        .padding(16)
        .consoleCard()
    }

    @ViewBuilder
    private var legend: some View {
        ChartLegendItem(title: "Fitness (CTL)", color: Palette.fitness)
        ChartLegendItem(title: "Fatigue (ATL)", color: Palette.fatigue)
        ChartLegendItem(title: "Form (TSB)", color: Palette.form, bar: true)
    }

    private func tiles(_ fitness: FitnessSnapshot) -> some View {
        let fatigue = library.series.last?.fatigue ?? 0
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                tileContent(fitness, fatigue: fatigue)
            }
            VStack(spacing: 10) {
                tileContent(fitness, fatigue: fatigue)
            }
        }
    }

    @ViewBuilder
    private func tileContent(_ fitness: FitnessSnapshot, fatigue: Double) -> some View {
        FormTile(title: "Fitness", value: fitness.fitness.displayRounded, color: Palette.fitness) {
            Text("over 42 days")
        }
        FormTile(title: "Fatigue", value: fatigue.displayRounded, color: Palette.fatigue) {
            Text("over 7 days")
        }
        FormTile(title: "Form", value: fitness.form.displayRounded, color: Palette.form) {
            Text(FormZone(form: fitness.form).title)
        }
    }

    private func explanation(_ delta: Double) -> LocalizedStringResource {
        let change = Formatting.signed(delta)
        if delta > 0.5 {
            return "Fitness changed by \(change) over the week — it's growing."
        } else if delta < -0.5 {
            return "Fitness changed by \(change) over the week — it's declining."
        }
        return "Fitness changed by \(change) over the week — it's holding steady."
    }
}

private struct FormTile<Caption: View>: View {
    let title: LocalizedStringKey
    let value: Int
    let color: Color
    @ViewBuilder let caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .consoleLabel()
            Text(value, format: .number)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            caption
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .padding(12)
        .consoleCard()
    }
}
