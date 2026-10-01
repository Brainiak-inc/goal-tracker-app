import SwiftUI
import TrainingKit

struct WeekCard: View {
    let plan: TrainingPlan
    let index: Int
    let comparison: [VolumeComparison]?
    let actuals: [UUID: WorkoutActual]
    let onToggle: (Int) -> Void
    let onAdd: (Int) -> Void
    let onEdit: (PlannedWorkout, Int) -> Void
    let onRemove: () -> Void

    @Environment(\.calendar) private var calendar

    private var week: PlanWeek { plan.weeks[index] }

    var body: some View {
        let progress = week.progress
        VStack(alignment: .leading, spacing: 0) {
            header(progress)
                .padding(.bottom, 6)
            ForEach(0..<PlanWeek.dayCount, id: \.self) { day in
                if day > 0 {
                    Divider().overlay(Color.white.opacity(0.05))
                }
                DayRow(
                    title: calendar.weekdayName(day),
                    date: plan.day(day, ofWeek: index, calendar: calendar),
                    workouts: week.days[day],
                    actuals: actuals,
                    isDone: week.done[day],
                    onToggle: { onToggle(day) },
                    onAdd: { onAdd(day) },
                    onEdit: { onEdit($0, day) }
                )
            }
            footer
        }
        .padding(16)
        .consoleCard()
        .overlay {
            if progress.isComplete {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.fitness.opacity(0.45), lineWidth: 1)
            }
        }
        .contextMenu {
            if plan.weeks.count > 1 {
                Button("Remove week", systemImage: "trash", role: .destructive, action: onRemove)
            }
        }
    }

    private func header(_ progress: WeekProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer()
                    status(progress)
                }
                VStack(alignment: .leading, spacing: 4) {
                    title
                    status(progress)
                }
            }
            if progress.total > 0 && !progress.isComplete {
                HStack(spacing: 3) {
                    ForEach(0..<progress.total, id: \.self) { item in
                        Capsule()
                            .fill(item < progress.done ? Palette.fitness : Color.white.opacity(0.12))
                            .frame(height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private var title: some View {
        Text(plan.weekTitle(index, calendar: calendar))
            .font(.headline)
            .foregroundStyle(Palette.text)
    }

    @ViewBuilder
    private func status(_ progress: WeekProgress) -> some View {
        if progress.isComplete {
            Label("Done", systemImage: "checkmark.seal.fill")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.fitness)
        } else if progress.total > 0 {
            Text("\(progress.done) of \(progress.total)")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let comparison {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan and actual")
                    .consoleLabel()
                ForEach(comparison, id: \.discipline) { item in
                    ComparisonRow(item: item)
                }
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.fitness.opacity(0.12)).frame(height: 1)
            }
        } else if !week.plannedVolume.isEmpty {
            PlannedVolume(volume: week.plannedVolume)
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle().fill(Palette.fitness.opacity(0.12)).frame(height: 1)
                }
        }
    }
}

private struct DayRow: View {
    let title: String
    let date: Date?
    let workouts: [PlannedWorkout]
    let actuals: [UUID: WorkoutActual]
    let isDone: Bool
    let onToggle: () -> Void
    let onAdd: () -> Void
    let onEdit: (PlannedWorkout) -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    private var isToday: Bool {
        date.map { calendar.isDateInToday($0) } ?? false
    }

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        layout {
            dayLabel
                .frame(width: stacked ? nil : 112, alignment: .leading)
            content
        }
        .padding(.vertical, 8)
        .opacity(isDone ? 0.55 : 1)
    }

    private var dayLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isToday ? Palette.fitness : Palette.text)
            if isToday {
                Text("today")
                    .font(.caption)
                    .foregroundStyle(Palette.fitness)
            } else if let date {
                Text(date, format: .dateTime.day().month(.wide))
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 10) {
            if workouts.isEmpty {
                Text("Rest")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                Spacer(minLength: 0)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle().strokeBorder(Palette.fitness.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        }
                        .foregroundStyle(Palette.fitness)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(Text("Add a workout on \(title)"))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(workouts) { workout in
                        Button {
                            onEdit(workout)
                        } label: {
                            WorkoutLine(workout: workout, actual: actuals[workout.id], units: units, isDone: isDone)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isDone ? Palette.fitness : Palette.fitness.opacity(0.5))
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isDone ? Text("Mark as not done") : Text("Mark as done"))
            }
        }
    }
}

private struct WorkoutLine: View {
    let workout: PlannedWorkout
    let actual: WorkoutActual?
    let units: UnitSystem
    let isDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(workout.discipline.title)
                        .foregroundStyle(Palette.text)
                    if let distance = workout.distance {
                        Text(Formatting.distance(distance, discipline: workout.discipline, units: units))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(Palette.text)
                    }
                }
                .font(.subheadline)
                let details = [workout.title, workout.note].filter { !$0.isEmpty }.joined(separator: " · ")
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                }
            }
            .strikethrough(isDone)
            if let actual {
                actualLine(actual)
            }
        }
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func actualLine(_ actual: WorkoutActual) -> some View {
        Group {
            if actual.distance > 0 {
                let done = Formatting.distance(actual.distance, discipline: workout.discipline, units: units)
                if let completion = actual.completion(of: workout.distance) {
                    let percent = Int((completion * 100).rounded())
                    Text("actual \(done) · \(percent)%")
                        .foregroundStyle(color(percent))
                } else {
                    Text("actual \(done)")
                        .foregroundStyle(Palette.fitness)
                }
            } else {
                Text("actual \(Duration.seconds(actual.duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))")
                    .foregroundStyle(Palette.fitness)
            }
        }
        .font(.system(.caption, design: .monospaced))
    }

    private func color(_ percent: Int) -> Color {
        if percent >= 90 { return Palette.success }
        if percent >= 50 { return Palette.form }
        return Palette.fatigue
    }
}

private struct ComparisonRow: View {
    let item: VolumeComparison
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    private var percent: Int {
        guard item.planned > 0 else { return 0 }
        return min(100, Int((item.actual / item.planned * 100).rounded()))
    }

    private var color: Color {
        if percent >= 90 { return Palette.success }
        if percent >= 50 { return Palette.form }
        return Palette.fatigue
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                name.frame(width: 84, alignment: .leading)
                bar.frame(width: 60)
                value
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    name
                    Spacer()
                    bar.frame(width: 60)
                }
                value
            }
        }
    }

    private var name: some View {
        Text(item.discipline.title)
            .font(.subheadline)
            .foregroundStyle(Palette.text.opacity(0.85))
    }

    @ViewBuilder
    private var bar: some View {
        if item.planned > 0 {
            ProgressBar(value: Double(percent) / 100, color: color)
        } else {
            Color.clear.frame(height: 6)
        }
    }

    private var value: some View {
        let actual = Formatting.distance(item.actual, discipline: item.discipline, units: units)
        return Group {
            if item.planned > 0 {
                let planned = Formatting.distance(item.planned, discipline: item.discipline, units: units)
                Text("\(actual) of \(planned) · \(percent)%")
            } else {
                Text("\(actual), not in the plan")
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(Palette.muted)
    }
}

private struct PlannedVolume: View {
    let volume: [DisciplineVolume]
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Planned volume")
                .consoleLabel()
            ForEach(volume, id: \.discipline) { item in
                HStack {
                    Text(item.discipline.title)
                        .foregroundStyle(Palette.text.opacity(0.85))
                    Spacer()
                    Text(Formatting.distance(item.distance, discipline: item.discipline, units: units))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Palette.text)
                }
                .font(.subheadline)
            }
        }
    }
}
