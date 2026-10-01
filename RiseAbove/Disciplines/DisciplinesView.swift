import SwiftUI
import TrainingKit

struct DisciplinesView: View {
    @Environment(ActivityLibrary.self) private var library
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @State private var selection: Discipline?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Discipline", selection: discipline) {
                        ForEach(Discipline.triathlon, id: \.self) { discipline in
                            Text(discipline.title).tag(discipline)
                        }
                    }
                    .pickerStyle(.segmented)

                    let activities = library.activities(for: discipline.wrappedValue)
                    if activities.isEmpty {
                        emptyCard
                    } else {
                        totals(activities)
                        formCard
                        volumeCard
                        workouts(activities)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background { ConsoleBackground() }
            .navigationTitle("Disciplines")
            .settingsToolbar()
        }
    }

    private var discipline: Binding<Discipline> {
        Binding {
            selection ?? Discipline.triathlon.max { library.activities(for: $0).count < library.activities(for: $1).count } ?? .run
        } set: {
            selection = $0
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No workouts in this discipline yet")
                .font(.headline)
                .foregroundStyle(Palette.text)
            Text("They appear here after an import or a sync with Apple Health.")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .consoleCard()
    }

    private func totals(_ activities: [Activity]) -> some View {
        let distance = activities.reduce(0) { $0 + ($1.distance ?? 0) }
        let duration = activities.reduce(0) { $0 + $1.duration }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                totalsContent(count: activities.count, distance: distance, duration: duration)
            }
            VStack(alignment: .leading, spacing: 12) {
                totalsContent(count: activities.count, distance: distance, duration: duration)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .consoleCard()
    }

    @ViewBuilder
    private func totalsContent(count: Int, distance: Double, duration: TimeInterval) -> some View {
        TotalItem(title: "Workouts") {
            Text(count, format: .number)
        }
        TotalItem(title: "Distance") {
            Text(Formatting.distance(distance, discipline: discipline.wrappedValue, units: units))
        }
        TotalItem(title: "Time") {
            Text(Duration.seconds(duration), format: .units(allowed: [.hours, .minutes], width: .abbreviated))
        }
    }

    @ViewBuilder
    private var formCard: some View {
        let series = library.series(for: discipline.wrappedValue)
        if let snapshot = FitnessSnapshot(series: series), let last = series.last {
            VStack(alignment: .leading, spacing: 10) {
                Text("Form · \(Text(discipline.wrappedValue.title))")
                    .consoleLabel()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { formLegend(snapshot, fatigue: last.fatigue) }
                    VStack(alignment: .leading, spacing: 6) { formLegend(snapshot, fatigue: last.fatigue) }
                }
                LoadChart(points: Array(series.suffix(42)), compact: true)
                    .frame(height: 100)
            }
            .padding(16)
            .consoleCard()
        }
    }

    @ViewBuilder
    private func formLegend(_ snapshot: FitnessSnapshot, fatigue: Double) -> some View {
        legendValue("Fitness", value: snapshot.fitness.displayRounded, color: Palette.fitness)
        legendValue("Fatigue", value: fatigue.displayRounded, color: Palette.fatigue)
        legendValue("Form", value: snapshot.form.displayRounded, color: Palette.form)
    }

    private func legendValue(_ title: LocalizedStringKey, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.text.opacity(0.85))
            Text(value, format: .number)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var volumeCard: some View {
        let weeks = library.weeklyVolume(discipline.wrappedValue)
        if weeks.reduce(0, +) > 0, let last = weeks.last {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Volume · 10 weeks").consoleLabel()
                        Spacer()
                        volumeValue(last, trend: Trend.volume(weeks))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume · 10 weeks").consoleLabel()
                        volumeValue(last, trend: Trend.volume(weeks))
                    }
                }
                VolumeBars(weeks: weeks)
            }
            .padding(16)
            .consoleCard()
        }
    }

    private func volumeValue(_ last: Double, trend: Trend?) -> some View {
        HStack(spacing: 6) {
            Text(Formatting.distance(last, discipline: discipline.wrappedValue, units: units))
                .font(.system(.subheadline, design: .monospaced))
            if let trend {
                Text(trend.arrow)
                    .foregroundStyle(trend == .up ? Palette.fitness : trend == .down ? Palette.fatigue : Palette.muted)
            }
        }
    }

    private func workouts(_ activities: [Activity]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("All workouts")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(activities.count, format: .number)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 6)
            LazyVStack(spacing: 0) {
                ForEach(Array(activities.reversed().enumerated()), id: \.element.identity) { index, activity in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                    ActivityRow(activity: activity, detail: .pace, showsDiscipline: false)
                }
            }
            .consoleCard(brackets: false)
        }
    }
}

private struct TotalItem<Value: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .consoleLabel()
            value
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}
