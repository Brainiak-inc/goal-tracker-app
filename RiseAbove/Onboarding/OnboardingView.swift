import SwiftUI
import TrainingKit

struct OnboardingView: View {
    static let completedKey = "onboardingCompleted"

    enum Step: Hashable {
        case sports
        case health
        case goal
    }

    @AppStorage(OnboardingView.completedKey) private var isCompleted = false
    @AppStorage(SportProfile.storageKey) private var storedProfile: SportProfile = .triathlon
    @Environment(HealthSync.self) private var healthSync
    @Environment(ActivityLibrary.self) private var library
    @Environment(RaceGoalStore.self) private var goal
    @State private var profile: SportProfile
    @State private var step: Step = .sports
    @State private var edge: Edge = .trailing

    init() {
        let stored = UserDefaults.standard.string(forKey: SportProfile.storageKey).flatMap(SportProfile.init(rawValue:))
        _profile = State(initialValue: stored ?? .empty)
    }

    private var steps: [Step] {
        [.sports, .health, .goal]
    }

    private var index: Int {
        steps.firstIndex(of: step) ?? 0
    }

    private var isLastStep: Bool {
        index == steps.count - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(step)
                    .switchTransition(edge: edge)
                    .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            footer
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background { ConsoleBackground() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { item in
                    Capsule()
                        .fill(item <= index ? Palette.fitness : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
            }
            .accessibilityHidden(true)
            HStack(spacing: 4) {
                if index > 0 {
                    Button {
                        move(to: steps[index - 1])
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 32, height: 44, alignment: .leading)
                    }
                    .accessibilityLabel(Text("Back"))
                }
                Text("Step \(index + 1) of \(steps.count)")
                    .consoleLabel()
                Spacer()
            }
            .frame(minHeight: 44)
        }
        .animation(.snappy, value: steps.count)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .sports:
            VStack(alignment: .leading, spacing: 18) {
                StepTitle(title: "What do you train?", text: "You can pick several. Your choice decides which disciplines and charts you see.")
                SportPicker(profile: $profile, allowsEmpty: true)
            }
        case .health:
            VStack(alignment: .leading, spacing: 18) {
                StepTitle(
                    title: healthSync.isEnabled ? "Workouts from Apple Health" : "Connect Apple Health",
                    text: "Workouts from Garmin Connect, Strava, and other apps will arrive on their own. The app only reads data and never changes anything in Health."
                )
                if healthSync.isEnabled {
                    if healthSync.isSyncing {
                        HealthLoadingCard()
                    }
                    HealthFoundCard(profile: $profile)
                } else {
                    HealthReadsCard()
                }
            }
        case .goal:
            VStack(alignment: .leading, spacing: 18) {
                StepTitle(title: "Training for a race?", text: "Set a goal, and the Readiness tab will show whether your training volume is on track.")
                GoalCard()
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            switch step {
            case .sports:
                Group {
                    if profile.isEmpty {
                        Text("Nothing selected yet")
                    } else {
                        Text("Selected: \(profile.summary.lowercased())")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Palette.text.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("You can change this anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                primaryButton("Continue", action: advance)
                    .disabled(profile.isEmpty)
                    .opacity(profile.isEmpty ? 0.4 : 1)
            case .health:
                if healthSync.isEnabled {
                    primaryButton(isLastStep ? "Finish" : "Continue", action: advance)
                } else {
                    HealthConnectButton(expands: true)
                        .buttonStyle(.consolePrimary)
                    secondaryButton("Later", action: advance)
                }
            case .goal:
                primaryButton("Finish", action: finish)
                if goal.config == nil {
                    secondaryButton("Skip", action: finish)
                }
            }
        }
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.consolePrimary)
    }

    private func secondaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(Palette.text.opacity(0.85))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        if step == .sports, !profile.isEmpty {
            storedProfile = profile
        }
        if isLastStep {
            finish()
        } else {
            move(to: steps[index + 1])
        }
    }

    private func move(to target: Step) {
        switchSelection(to: target, selection: $step, values: steps, edge: $edge)
    }

    private func finish() {
        storedProfile = profile.isEmpty ? .triathlon : profile
        isCompleted = true
    }
}

private struct StepTitle: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(text)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct HealthReadsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What the app reads from Health")
                .consoleLabel()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)
            ReadRow(symbol: "calendar", color: Palette.fitness, title: "Workouts", detail: "sport, date, and duration")
            Divider().overlay(Color.white.opacity(0.06))
            ReadRow(symbol: "point.topleft.down.to.point.bottomright.curvepath", color: Palette.fitness, title: "Distance", detail: "for volume and pace")
            Divider().overlay(Color.white.opacity(0.06))
            ReadRow(symbol: "heart", color: Palette.danger, title: "Heart rate", detail: "to calculate load, fitness, and form")
        }
        .consoleCard()
    }
}

private struct ReadRow: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct HealthFoundCard: View {
    @Binding var profile: SportProfile

    @Environment(ActivityLibrary.self) private var library

    private var recent: [Activity] {
        let since = library.calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
        return library.activities.filter { $0.start >= since }
    }

    var body: some View {
        let recent = recent
        let suggested = Discipline.triathlon.filter { discipline in
            !profile.disciplines.contains(discipline) && recent.contains { $0.discipline == discipline }
        }
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Found in Health over the past year")
                    .consoleLabel()
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                ForEach([Discipline.run, .bike, .swim], id: \.self) { discipline in
                    FoundRow(
                        discipline: discipline,
                        count: recent.filter { $0.discipline == discipline }.count,
                        isSelected: profile.disciplines.contains(discipline)
                    ) {
                        if let sport = Sport(rawValue: discipline.rawValue) {
                            withAnimation(.snappy) {
                                profile.toggle(sport, allowsEmpty: true)
                            }
                        }
                    }
                    Divider().overlay(Color.white.opacity(0.06))
                }
                OtherRow(count: recent.filter { !$0.discipline.isTriathlon }.count)
            }
            .consoleCard()
            if !suggested.isEmpty {
                Text("Health has workouts in sports you haven't picked. Add them to see their volume separately.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FoundRow: View {
    let discipline: Discipline
    let count: Int
    let isSelected: Bool
    let add: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: discipline.symbol)
                .font(.body)
                .foregroundStyle(isSelected ? Palette.fitness : count > 0 ? Palette.text.opacity(0.8) : Palette.muted)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(discipline.title)
                    .font(.headline)
                    .foregroundStyle(count > 0 || isSelected ? Palette.text : Palette.muted)
                Group {
                    if count > 0 {
                        Text("\(count) workouts")
                    } else {
                        Text("No workouts")
                    }
                }
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.fitness)
                    .accessibilityLabel(Text("Selected"))
            } else if count > 0 {
                Button("Add", action: add)
                    .buttonStyle(.consoleChip(isActive: false))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct OtherRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Discipline.strength.symbol)
                .font(.body)
                .foregroundStyle(Palette.muted)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Other")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Group {
                    if count > 0 {
                        Text("\(count) workouts")
                    } else {
                        Text("No workouts")
                    }
                }
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Palette.muted)
                Text("Strength and other workouts count toward overall load.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct GoalCard: View {
    @Environment(RaceGoalStore.self) private var goal
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @State private var editsGoal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let config = goal.config {
                Text("Your goal")
                    .consoleLabel()
                Text(config.title(units: units))
                    .font(.title3.bold())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(config.details(units: units))
                    .foregroundStyle(Palette.muted)
                Button("Change goal") {
                    editsGoal = true
                }
                .buttonStyle(.consoleSecondary)
            } else {
                Text("A distance or a time limit, race day, and your target. The goal can be changed later on the Readiness tab.")
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    editsGoal = true
                } label: {
                    Label("Set a goal", systemImage: "flag.checkered")
                }
                .buttonStyle(.consolePrimary)
            }
        }
        .padding(18)
        .consoleCard()
        .sheet(isPresented: $editsGoal) {
            RaceGoalSheet(config: goal.config)
        }
    }
}
