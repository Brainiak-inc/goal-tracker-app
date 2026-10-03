import SwiftUI
import TrainingKit

struct ReadinessView: View {
    @Environment(ActivityLibrary.self) private var library
    @Environment(RaceGoalStore.self) private var goal
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @State private var editsGoal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let config = goal.config {
                        let readiness = ReadinessCalculator.compute(
                            config: config,
                            activities: library.activities,
                            fitness: library.fitness,
                            settings: library.settings,
                            now: .now,
                            calendar: library.calendar
                        )
                        Text(config.summary(units: units))
                            .consoleLabel()
                        NavigationLink {
                            ReadinessGuideView(readiness: readiness, config: config)
                        } label: {
                            ReadinessHero(readiness: readiness)
                        }
                        .buttonStyle(.plain)
                        if !readiness.hasVolume {
                            Text("There's no volume to assess yet. Import your workouts.")
                                .foregroundStyle(Palette.fatigue)
                                .padding(16)
                                .consoleCard(brackets: false)
                        }
                        if let prediction = readiness.prediction {
                            PredictionCard(prediction: prediction, config: config)
                        }
                        DisciplineReadinessCard(readiness: readiness, hasManualNorms: config.hasManualNorms)
                        NextWeekCard(steps: readiness.nextWeek.filter { !$0.isDone })
                        if readiness.prediction == nil {
                            PaceCard(checks: readiness.pace)
                        }
                        NavigationLink {
                            ReadinessGuideView(readiness: readiness, config: config)
                        } label: {
                            HStack {
                                Label("How readiness is calculated", systemImage: "info.circle")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                            }
                            .foregroundStyle(Palette.fitness)
                            .padding(16)
                            .consoleCard(brackets: false)
                        }
                        .buttonStyle(.plain)
                        Text("A volume-based estimate to guide you, not a medical assessment.")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    } else {
                        GoalInvitation {
                            editsGoal = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background { ConsoleBackground() }
            .navigationTitle("Readiness")
            .toolbar {
                if goal.config != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit goal", systemImage: "pencil") {
                            editsGoal = true
                        }
                    }
                }
            }
            .settingsToolbar()
            .sheet(isPresented: $editsGoal) {
                RaceGoalSheet(config: goal.config)
            }
        }
    }

}

private struct GoalInvitation: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How ready are you for the start?")
                .font(.title3.bold())
                .foregroundStyle(Palette.text)
            Text("Pick a distance and a target time. The estimate compares your recent weekly volume and longest sessions with what the race needs.")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Label("Set a race goal", systemImage: "scope")
            }
            .buttonStyle(.consolePrimary)
        }
        .padding(18)
        .consoleCard()
    }
}

private struct ReadinessHero: View {
    let readiness: Readiness

    var body: some View {
        VStack(spacing: 12) {
            ReadinessRing(percent: readiness.overall)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips }
                VStack(spacing: 8) { chips }
            }
            if readiness.disciplines.count > 1 {
                HStack(spacing: 4) {
                    Text("Weakest link:")
                    Text(readiness.limiting.title)
                        .foregroundStyle(Palette.fatigue)
                }
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
            }
            if let note = fitnessNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .consoleCard()
    }

    @ViewBuilder
    private var chips: some View {
        if let status = readiness.status {
            Text(statusText(status))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status == .behind ? Palette.warning : Palette.success)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((status == .behind ? Palette.warning : Palette.success).opacity(0.12), in: Capsule())
        }
        etaText
            .font(.subheadline)
            .foregroundStyle(Palette.text.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var etaText: Text {
        let months = readiness.monthsToReady
        if months <= 0 {
            return Text("Volumes are at the target level")
        }
        if months >= 12 {
            let years = (Double(months) / 12).formatted(.number.precision(.fractionLength(1)))
            return Text("\(Text("≈ \(months) months")) · \(Text("about \(years) years"))")
        }
        return Text("≈ \(months) months")
    }

    private func statusText(_ status: RaceStatus) -> LocalizedStringResource {
        switch status {
        case .ahead:
            return "Ahead of schedule"
        case .onTrack:
            return "On track"
        case .behind:
            let weeks = max(1, (Double(readiness.monthsToReady) * 4.345 - Double(readiness.weeksToRace ?? 0)).displayRounded)
            return "Behind by about \(weeks) weeks"
        }
    }

    private var fitnessNote: LocalizedStringResource? {
        guard readiness.fitness != nil else { return nil }
        if readiness.fitnessBonus > 0 {
            return "Fitness is growing, so the volume estimate of \(readiness.volumeScore)% was raised to \(readiness.overall)%."
        }
        if readiness.fitnessBonus < 0 {
            return "Fitness is declining, so the volume estimate of \(readiness.volumeScore)% was lowered to \(readiness.overall)%."
        }
        return "Fitness is steady, so the estimate is based on volume alone."
    }
}

private struct ReadinessRing: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(Palette.level(percent), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .inset(by: 18)
                .stroke(Palette.fitness.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            VStack(spacing: 4) {
                Text("\(percent)%")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.level(percent))
                    .minimumScaleFactor(0.6)
                Text("overall")
                    .consoleLabel()
            }
            .padding(24)
        }
        .frame(width: 170, height: 170)
        .accessibilityElement(children: .combine)
    }
}

private struct DisciplineReadinessCard: View {
    let readiness: Readiness
    let hasManualNorms: Bool
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    private var isSingle: Bool {
        readiness.disciplines.count == 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Group {
                    if isSingle {
                        Text("Training volume")
                    } else {
                        Text("By discipline")
                    }
                }
                .consoleLabel()
                Spacer()
                if hasManualNorms {
                    Text("Own targets")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.fitness)
                }
            }
            ForEach(readiness.disciplines, id: \.discipline) { item in
                let isWeakest = !isSingle && item.discipline == readiness.limiting
                let color = isWeakest ? Palette.fatigue : Palette.level(item.percent)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.discipline.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isWeakest ? Palette.fatigue : Palette.text)
                        Spacer()
                        Text("\(item.percent)%")
                            .font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .foregroundStyle(color)
                    }
                    ProgressBar(value: Double(item.percent) / 100, color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Text("per week")): \(distance(item.weeklyDistance, of: item.targetWeeklyDistance, item.discipline))")
                        Text("\(Text("longest")): \(distance(item.longestDistance, of: item.targetLongestDistance, item.discipline))")
                        if let fitness = item.fitness, let target = item.targetFitness {
                            Text("\(Text("fitness")): \(Text("\(fitness.displayRounded) of \(target.displayRounded)").foregroundStyle(Palette.text.opacity(0.85)))")
                        }
                        if let weeks = item.activeWeeks {
                            Text("\(Text("weeks with training")): \(Text("\(weeks) of 6").foregroundStyle(Palette.text.opacity(0.85)))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .consoleCard()
    }

    private func distance(_ value: Double, of target: Double, _ discipline: Discipline) -> Text {
        let current = Formatting.distance(value, discipline: discipline, units: units)
        let goal = Formatting.distance(target, discipline: discipline, units: units)
        return Text("\(current) of \(goal)")
            .foregroundStyle(Palette.text.opacity(0.85))
    }
}

private struct NextWeekCard: View {
    let steps: [WeeklyStep]
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    var body: some View {
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("This week")
                    .consoleLabel()
                ForEach(steps, id: \.discipline) { step in
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            name(step)
                            Spacer()
                            value(step)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            name(step)
                            value(step)
                        }
                    }
                }
                Text("A safe weekly increase towards the target volume.")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(16)
            .consoleCard()
        }
    }

    private func name(_ step: WeeklyStep) -> some View {
        Text(step.discipline.title)
            .foregroundStyle(Palette.text)
    }

    private func value(_ step: WeeklyStep) -> some View {
        HStack(spacing: 6) {
            Text(Formatting.distance(step.currentDistance, discipline: step.discipline, units: units))
                .foregroundStyle(Palette.muted)
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(Palette.muted)
            Text(Formatting.distance(step.suggestedDistance, discipline: step.discipline, units: units))
                .foregroundStyle(Palette.fitness)
                .bold()
        }
        .font(.system(.subheadline, design: .monospaced))
    }
}

private struct PredictionCard: View {
    let prediction: RacePrediction
    let config: RaceConfig
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    private var color: Color {
        if config.isTimed {
            guard config.hasGoalDistance else { return Palette.fitness }
            return prediction.distance >= config.distance.leg(for: prediction.discipline) ? Palette.success : Palette.fatigue
        }
        return prediction.time <= config.targetTime ? Palette.success : Palette.fatigue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Forecast")
                .consoleLabel()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    value
                    Spacer()
                    goal
                }
                VStack(alignment: .leading, spacing: 4) {
                    value
                    goal
                }
            }
            Text(basis)
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .consoleCard()
        .accessibilityElement(children: .combine)
    }

    private var value: some View {
        Group {
            if config.isTimed {
                Text(Formatting.distance(prediction.distance, discipline: prediction.discipline, units: units))
            } else {
                Text(Formatting.raceTime(prediction.time))
            }
        }
        .font(.system(.title, design: .monospaced, weight: .bold))
        .foregroundStyle(color)
    }

    private var goal: some View {
        Group {
            if config.isTimed {
                if config.hasGoalDistance {
                    Text("goal \(Formatting.distance(config.distance.leg(for: prediction.discipline), discipline: prediction.discipline, units: units))")
                } else {
                    Text("in \(Int((prediction.time / 3600).rounded())) hours")
                }
            } else {
                Text("goal \(Formatting.raceTime(config.targetTime))")
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.muted)
    }

    private var basis: LocalizedStringResource {
        let effort = Formatting.distance(prediction.effortDistance, discipline: prediction.discipline, units: units)
        let time = Formatting.raceTime(prediction.effortDuration)
        let date = prediction.effortDate.formatted(.dateTime.day().month(.wide))
        return "From your best recent effort, \(effort) in \(time) on \(date). It assumes a race effort and gets slower when your long sessions fall short of the distance."
    }
}

private struct PaceCard: View {
    let checks: [PaceCheck]
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pace for the target time")
                .consoleLabel()
            ForEach(checks, id: \.discipline) { check in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(check.discipline.title)
                            .foregroundStyle(Palette.text)
                        Spacer()
                        if let current = check.currentSpeed {
                            HStack(spacing: 6) {
                                Text(pace(current, check.discipline))
                                    .font(.system(.subheadline, design: .monospaced))
                                Image(systemName: check.isOnPace ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .accessibilityLabel(check.isOnPace ? Text("Fast enough") : Text("Too slow"))
                            }
                            .foregroundStyle(check.isOnPace ? Palette.success : Palette.fatigue)
                        } else {
                            Text("no data")
                                .font(.subheadline)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    Text("needed: \(pace(check.requiredSpeed, check.discipline))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(16)
        .consoleCard()
    }

    private func pace(_ speed: Double, _ discipline: Discipline) -> String {
        Formatting.pace(distance: speed, duration: 1, discipline: discipline, units: units) ?? "—"
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule().fill(color)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
