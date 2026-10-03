import SwiftUI
import TrainingKit

struct ReadinessGuideView: View {
    let readiness: Readiness
    let config: RaceConfig

    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Readiness compares your recent training with what the race needs. It is an estimate to guide you, not a medical assessment.")
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                overallCard
                ForEach(readiness.disciplines, id: \.discipline) { item in
                    DisciplineBreakdown(item: item, units: units)
                }
                targetsCard
                timeCard
                forecastCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { ConsoleBackground() }
        .navigationTitle("How readiness is calculated")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overallCard: some View {
        GuideSection(title: "Overall", value: Text("\(readiness.overall)%"), color: Palette.level(readiness.overall)) {
            if readiness.disciplines.count > 1 {
                Text("Half of it comes from the weakest discipline and half from the average of all of them, so one lagging discipline holds the whole race back.")
            } else {
                Text("It is the readiness of your only discipline.")
            }
            if readiness.fitness != nil {
                Text("The fitness trend adds or removes up to 4 points. Now: \(Text(readiness.fitnessBonus, format: .number.sign(strategy: .always()))).")
            }
        }
    }

    private var targetsCard: some View {
        GuideSection(title: "Targets") {
            if config.hasManualNorms {
                Text("You set your own targets for this goal. They can be changed in the goal settings.")
            } else if config.isTimed, !config.hasGoalDistance {
                Text("Targets come from the time limit at an easy pace, since there is no goal distance.")
            } else {
                Text("Targets come from the race distance and your target time. The faster the goal, the higher the targets, up to twice the base for a slow finish.")
                if !config.isTimed {
                    Text("Cutoff for this distance: \(Formatting.raceTime(config.planningDistance.cutoff)).")
                }
            }
        }
    }

    private var timeCard: some View {
        GuideSection(title: "Time to be ready") {
            if readiness.monthsToReady <= 0 {
                Text("Your weekly volumes are already at the target level.")
            } else if config.fromZero {
                Text("If weekly volume grows by 4.5 percent a week, the targets are reached in about \(readiness.monthsToReady) months, with three extra months of buffer for a start from scratch.")
            } else {
                Text("If weekly volume grows by 7 percent a week, the targets are reached in about \(readiness.monthsToReady) months, including a month of buffer.")
            }
        }
    }

    @ViewBuilder
    private var forecastCard: some View {
        if readiness.prediction != nil {
            GuideSection(title: "Forecast") {
                Text("The forecast takes your best effort of the last 12 weeks and recalculates it to the race distance with Riegel's formula, a standard method in running.")
                Text("It gets slower when your longest sessions fall short of the distance or your weekly volume is below the target, because both limit how long you can hold the pace.")
            }
        } else if !readiness.pace.isEmpty {
            GuideSection(title: "Pace") {
                Text("Pace compares your average training speed over 12 weeks with the speed the target time needs in each discipline.")
            }
        }
    }
}

private struct DisciplineBreakdown: View {
    let item: DisciplineReadiness
    let units: UnitSystem

    var body: some View {
        GuideSection(title: item.discipline.title, value: Text("\(item.percent)%"), color: Palette.level(item.percent)) {
            VStack(spacing: 10) {
                ForEach(item.components, id: \.kind) { component in
                    ComponentRow(component: component, detail: detail(for: component.kind))
                }
            }
            Text("Each part counts up to 100 percent and is multiplied by its weight.")
                .font(.caption)
        }
    }

    private func detail(for kind: ReadinessComponent.Kind) -> Text {
        switch kind {
        case .volume:
            Text("\(distance(item.weeklyDistance)) of \(distance(item.targetWeeklyDistance)) a week")
        case .longest:
            Text("\(distance(item.longestDistance)) of \(distance(item.targetLongestDistance))")
        case .load:
            Text("\((item.fitness ?? 0).displayRounded) of \((item.targetFitness ?? 0).displayRounded)")
        case .consistency:
            Text("\(item.activeWeeks ?? 0) of 6")
        }
    }

    private func distance(_ meters: Double) -> String {
        Formatting.distance(meters, discipline: item.discipline, units: units)
    }
}

private struct ComponentRow: View {
    let component: ReadinessComponent
    let detail: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(verbatim: "\(Int((component.ratio * 100).rounded()))% × \(Int((component.weight * 100).rounded()))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
            ProgressBar(value: component.ratio, color: Palette.level(Int((component.ratio * 100).rounded())))
            VStack(alignment: .leading, spacing: 2) {
                detail
                    .foregroundStyle(Palette.text.opacity(0.85))
                hint
            }
            .font(.caption)
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: Text {
        switch component.kind {
        case .volume: Text("Weekly volume")
        case .longest: Text("Longest session")
        case .load: Text("Fitness")
        case .consistency: Text("Weeks with training")
        }
    }

    private var hint: Text {
        switch component.kind {
        case .volume: Text("recent weeks count more, and the taper before a race is not penalised")
        case .longest: Text("last 12 weeks, older sessions count a little less")
        case .load: Text("load from heart rate, so intensity matters too")
        case .consistency: Text("out of the last six weeks")
        }
    }
}

private struct GuideSection<Content: View>: View {
    let title: LocalizedStringResource
    var value: Text?
    var color: Color = Palette.text
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .consoleLabel()
                Spacer()
                if let value {
                    value
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(color)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .font(.subheadline)
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .consoleCard()
    }
}
