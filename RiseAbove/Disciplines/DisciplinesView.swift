import SwiftUI
import TrainingKit

struct DisciplinesView: View {
    @Environment(ActivityLibrary.self) private var library
    @Environment(HealthSync.self) private var healthSync
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon
    @State private var selection: Discipline?
    @State private var selectedWeek: Int?
    @State private var selectedActivity: Activity?
    @State private var edge: Edge = .trailing

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if profile.single == nil {
                        Picker("Discipline", selection: animatedSwitch(discipline, among: profile.disciplines, edge: $edge)) {
                            ForEach(profile.disciplines, id: \.self) { discipline in
                                Text(discipline.title).tag(discipline)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    disciplineContent
                        .id(discipline.wrappedValue)
                        .switchTransition(edge: edge)
                        .swipeToSwitch(discipline, among: profile.disciplines, edge: $edge)
                        .onChange(of: discipline.wrappedValue) {
                            selectedWeek = nil
                        }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable {
                await healthSync.sync()
            }
            .background { ConsoleBackground() }
            .navigationTitle(Text(profile.single?.title ?? "Disciplines"))
            .settingsToolbar()
            .sheet(item: $selectedActivity) { activity in
                ActivityDetailSheet(activity: activity)
            }
        }
    }

    private var discipline: Binding<Discipline> {
        Binding {
            let disciplines = profile.disciplines
            if let selection, disciplines.contains(selection) {
                return selection
            }
            return disciplines.max { library.activities(for: $0).count < library.activities(for: $1).count } ?? .run
        } set: {
            selection = $0
        }
    }

    private var disciplineContent: some View {
        let activities = library.activities(for: discipline.wrappedValue)
        return VStack(alignment: .leading, spacing: 14) {
            if activities.isEmpty {
                emptyCard
            } else {
                totals(activities)
                formCard
                volumeCard
                workouts(activities)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
        if weeks.reduce(0, +) > 0 {
            let starts = library.weekStarts(weeks.count)
            let shown = selectedWeek ?? weeks.count - 1
            let isCurrent = shown == weeks.count - 1
            let trend = isCurrent || shown == 0 ? nil : Trend.volume(Array(weeks[...shown]))
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        volumeTitle(starts[shown], isCurrent: isCurrent)
                        Spacer()
                        volumeValue(weeks[shown], trend: trend)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        volumeTitle(starts[shown], isCurrent: isCurrent)
                        volumeValue(weeks[shown], trend: trend)
                    }
                }
                VolumeBars(
                    weeks: weeks,
                    labels: zip(starts, weeks).map { "\(weekRange($0)), \(Formatting.distance($1, discipline: discipline.wrappedValue, units: units))" },
                    selection: $selectedWeek
                )
                Group {
                    if selectedWeek == nil {
                        Text("Tap a week to see its workouts.")
                    } else {
                        Text("Tap the week again to show all workouts.")
                    }
                }
                .font(.caption)
                .foregroundStyle(Palette.muted)
            }
            .padding(16)
            .consoleCard()
        }
    }

    private func volumeTitle(_ start: Date, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Volume · 10 weeks").consoleLabel()
            Group {
                if isCurrent {
                    Text("This week · \(weekRange(start))")
                } else {
                    Text(weekRange(start))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedWeek == nil ? Palette.text : Palette.fitness)
        }
    }

    private func weekRange(_ start: Date) -> String {
        let end = library.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let format = Date.FormatStyle.dateTime.day().month(.wide)
        return "\(start.formatted(format)) — \(end.formatted(format))"
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

    private func workouts(_ all: [Activity]) -> some View {
        let activities = filtered(all)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if selectedWeek == nil {
                    Text("All workouts")
                        .font(.title3.bold())
                        .foregroundStyle(Palette.text)
                } else {
                    Text("Workouts this week")
                        .font(.title3.bold())
                        .foregroundStyle(Palette.text)
                }
                Spacer()
                if selectedWeek != nil {
                    Button("Show all") {
                        withAnimation(.snappy) { selectedWeek = nil }
                    }
                    .font(.subheadline)
                } else {
                    Text(activities.count, format: .number)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.top, 6)
            if activities.isEmpty {
                Text("No workouts in this week.")
                    .foregroundStyle(Palette.muted)
                    .padding(16)
                    .consoleCard(brackets: false)
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(activities.reversed().enumerated()), id: \.element.identity) { index, activity in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                    Button {
                        selectedActivity = activity
                    } label: {
                        ActivityRow(activity: activity, detail: .pace, showsDiscipline: false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .consoleCard(brackets: false)
        }
    }
}

private extension DisciplinesView {
    func filtered(_ activities: [Activity]) -> [Activity] {
        guard let selectedWeek else { return activities }
        let starts = library.weekStarts()
        guard starts.indices.contains(selectedWeek) else { return activities }
        let start = starts[selectedWeek]
        let end = library.calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return activities.filter { $0.start >= start && $0.start < end }
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
