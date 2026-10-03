import SwiftUI
import TrainingKit

struct OverviewView: View {
    @Environment(ActivityLibrary.self) private var library
    @Environment(HealthSync.self) private var healthSync

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if healthSync.isSyncing, healthSync.progress != nil || !library.hasData {
                        HealthLoadingCard()
                    }
                    if !library.activities.isEmpty {
                        if let fitness = library.fitness {
                            HUDCard(fitness: fitness, trend: library.fitnessTrend, weeklyStress: library.weeklyStress)
                            FormCard(fitness: fitness, points: Array(library.series.suffix(42)))
                        }
                        VolumeCard()
                        RecentActivities()
                    } else if library.hasData {
                        PeriodEmptyCard()
                    } else if !healthSync.isSyncing {
                        EmptyLibraryCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.snappy, value: healthSync.isSyncing)
            }
            .refreshable {
                await healthSync.sync()
            }
            .background { ConsoleBackground() }
            .navigationTitle("Overview")
            .settingsToolbar(showsSync: false)
        }
    }
}

private struct EmptyLibraryCard: View {
    @Environment(HealthSync.self) private var healthSync

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add your training data")
                .font(.title3.bold())
                .foregroundStyle(Palette.text)
            if healthSync.isEnabled {
                Text("Apple Health is connected, but there are no workouts in it yet. Check that Garmin Connect shares workouts with Health, or import a CSV export.")
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HealthSyncStatus()
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                GarminImportButton()
                    .buttonStyle(.consoleSecondary)
            } else {
                Text("Connect Apple Health to get workouts from Garmin Connect and other apps automatically, or import a CSV export.")
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if healthSync.isAvailable {
                    HealthConnectButton()
                        .buttonStyle(.consolePrimary)
                }
                GarminImportButton()
                    .buttonStyle(.consoleSecondary)
            }
            WebBackupImportButton(title: "Restore from backup")
                .buttonStyle(.consoleSecondary)
        }
        .padding(18)
        .consoleCard()
    }
}

private struct PeriodEmptyCard: View {
    @Environment(ActivityLibrary.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let since = library.visibleSince {
                Text("No workouts since \(Text(since, format: .dateTime.day().month(.wide).year()))")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
            }
            Text("Earlier workouts are hidden. You can change the period in Settings → Workout period.")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .consoleCard()
    }
}

private struct HUDCard: View {
    let fitness: FitnessSnapshot
    let trend: (trend: Trend, delta: Double)?
    let weeklyStress: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                metrics
            }
            VStack(alignment: .leading, spacing: 14) {
                metrics
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .consoleCard()
    }

    @ViewBuilder
    private var metrics: some View {
        GuideLink(.form) {
            HUDMetric(title: "Form", color: Palette.form) {
                Text(fitness.form.displayRounded, format: .number)
            } caption: {
                Text(FormZone(form: fitness.form).title)
            }
        }
        GuideLink(.fitness) {
            HUDMetric(title: "Fitness", color: Palette.fitness) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(fitness.fitness.displayRounded, format: .number)
                if let trend {
                    Text(trend.trend.arrow)
                        .font(.footnote)
                }
            }
            } caption: {
                if let trend {
                    Text("\(Formatting.signed(trend.delta)) per week")
                } else {
                    Text("trend after a week of data")
                }
            }
        }
        GuideLink(.load) {
            HUDMetric(title: "Load", color: Palette.fatigue) {
                Text(weeklyStress.displayRounded, format: .number)
            } caption: {
                Text("TSS over 7 days")
            }
        }
    }
}

private struct GuideLink<Label: View>: View {
    let metric: MetricsGuideView.Metric
    @ViewBuilder let label: Label

    init(_ metric: MetricsGuideView.Metric, @ViewBuilder label: () -> Label) {
        self.metric = metric
        self.label = label()
    }

    var body: some View {
        NavigationLink {
            MetricsGuideView(focus: metric)
        } label: {
            label
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows what this number means"))
    }
}

private struct HUDMetric<Value: View, Caption: View>: View {
    let title: LocalizedStringKey
    let color: Color
    @ViewBuilder let value: Value
    @ViewBuilder let caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .consoleLabel()
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
                    .accessibilityHidden(true)
            }
            value
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            caption
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

private struct FormCard: View {
    let fitness: FitnessSnapshot
    let points: [LoadPoint]

    var body: some View {
        NavigationLink {
            FormView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Form")
                        .consoleLabel()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Fitness")
                        .foregroundStyle(Palette.text)
                    Text(fitness.fitness.displayRounded, format: .number)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(Palette.fitness)
                }
                LoadChart(points: points, compact: true)
                    .frame(height: 64)
            }
            .padding(16)
            .consoleCard()
        }
        .buttonStyle(.plain)
    }
}

private struct VolumeCard: View {
    @Environment(ActivityLibrary.self) private var library
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon
    @Environment(AppNavigation.self) private var navigation

    private var rows: [(discipline: Discipline, current: Double, previous: Double)] {
        profile.disciplines.compactMap { discipline in
            let weeks = library.weeklyVolume(discipline)
            guard weeks.reduce(0, +) > 0, let current = weeks.last else { return nil }
            return (discipline, current, weeks.dropLast().last ?? 0)
        }
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume this week")
                    .consoleLabel()
                ForEach(rows, id: \.discipline) { row in
                    Button {
                        navigation.show(row.discipline)
                    } label: {
                        HStack(spacing: 10) {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline) {
                                    name(row.discipline)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        current(row)
                                        previous(row)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    name(row.discipline)
                                    current(row)
                                    previous(row)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.muted)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the discipline"))
                }
            }
            .padding(16)
            .consoleCard()
        }
    }

    private func name(_ discipline: Discipline) -> some View {
        Text(discipline.title)
            .foregroundStyle(Palette.text)
    }

    private func current(_ row: (discipline: Discipline, current: Double, previous: Double)) -> some View {
        Text(Formatting.distance(row.current, discipline: row.discipline, units: units))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Palette.text)
    }

    private func previous(_ row: (discipline: Discipline, current: Double, previous: Double)) -> some View {
        Text("previous week: \(Formatting.distance(row.previous, discipline: row.discipline, units: units))")
            .font(.caption)
            .foregroundStyle(Palette.muted)
    }
}

private struct RecentActivities: View {
    @Environment(ActivityLibrary.self) private var library
    @Environment(HealthSync.self) private var healthSync
    @State private var selected: Activity?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent")
                        .font(.title3.bold())
                        .foregroundStyle(Palette.text)
                    Spacer()
                    NavigationLink {
                        AllActivitiesView()
                    } label: {
                        HStack(spacing: 4) {
                            Text("All")
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                syncStatus
            }
            .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(Array(library.recent.prefix(8).enumerated()), id: \.element.identity) { index, activity in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                    Button {
                        selected = activity
                    } label: {
                        ActivityRow(activity: activity, detail: .stress(library.stress(for: activity)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .consoleCard(brackets: false)
        }
        .sheet(item: $selected) { activity in
            ActivityDetailSheet(activity: activity)
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        if healthSync.isEnabled {
            HStack(spacing: 4) {
                Text(verbatim: "Health ·")
                HealthSyncStatus()
            }
            .font(.footnote)
            .foregroundStyle(Palette.muted)
        }
    }
}
