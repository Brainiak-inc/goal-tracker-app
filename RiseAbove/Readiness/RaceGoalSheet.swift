import SwiftUI
import TrainingKit

struct RaceGoalSheet: View {
    @Environment(RaceGoalStore.self) private var goal
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon

    @State private var sport: Sport
    @State private var isTimed: Bool
    @State private var preset: RacePreset?
    @State private var legTexts: [Discipline: String]
    @State private var timeLimitHours: Int
    @State private var goalDistanceText: String
    @State private var hasGoalDistance: Bool
    @State private var hasDate: Bool
    @State private var raceDay: Date
    @State private var hours: Int
    @State private var minutes: Int
    @State private var fromZero: Bool
    @State private var usesManualNorms: Bool
    @State private var weeklyTexts: [Discipline: String]
    @State private var longestTexts: [Discipline: String]

    init(config: RaceConfig?) {
        let defaults = UserDefaults.standard
        let profile = defaults.string(forKey: SportProfile.storageKey).flatMap(SportProfile.init(rawValue:)) ?? .triathlon
        let units = defaults.string(forKey: UnitSystem.storageKey).flatMap(UnitSystem.init(rawValue:)) ?? .metric
        let sport = config?.distance.sport ?? Self.defaultSport(for: profile)
        let distance = config?.distance ?? RaceDistance(preset: Self.defaultPreset(for: sport))
        let isTimed = config?.isTimed ?? false

        var legTexts: [Discipline: String] = [:]
        if distance.isCustom, !isTimed {
            for discipline in distance.disciplines {
                legTexts[discipline] = InputUnit(discipline: discipline, units: units).text(distance.leg(for: discipline))
            }
        }
        var weeklyTexts: [Discipline: String] = [:]
        var longestTexts: [Discipline: String] = [:]
        for norm in config?.manualNorms ?? [] {
            let unit = InputUnit(discipline: norm.discipline, units: units)
            weeklyTexts[norm.discipline] = unit.text(norm.weekly)
            longestTexts[norm.discipline] = unit.text(norm.longest)
        }
        let target = Int(config?.targetTime ?? distance.cutoff)

        _sport = State(initialValue: sport)
        _isTimed = State(initialValue: isTimed)
        _preset = State(initialValue: isTimed ? Self.defaultPreset(for: sport) : distance.preset)
        _legTexts = State(initialValue: legTexts)
        _timeLimitHours = State(initialValue: Int(((config?.timeLimit ?? 6 * 3600) / 3600).rounded()))
        let hasGoalDistance = isTimed && distance.total > 0
        _goalDistanceText = State(initialValue: hasGoalDistance
            ? distance.disciplines.first.map { InputUnit(discipline: $0, units: units).text(distance.leg(for: $0)) } ?? ""
            : "")
        _hasGoalDistance = State(initialValue: hasGoalDistance)
        _hasDate = State(initialValue: config?.raceDay != nil)
        _raceDay = State(initialValue: config?.raceDay ?? Calendar.current.date(byAdding: .month, value: 9, to: .now) ?? .now)
        _hours = State(initialValue: target / 3600)
        _minutes = State(initialValue: (target % 3600) / 60)
        _fromZero = State(initialValue: config?.fromZero ?? false)
        _usesManualNorms = State(initialValue: config?.hasManualNorms ?? false)
        _weeklyTexts = State(initialValue: weeklyTexts)
        _longestTexts = State(initialValue: longestTexts)
    }

    var body: some View {
        NavigationStack {
            Form {
                if sports.count > 1 {
                    Section {
                        ChoiceGrid(items: sports, selection: sport, title: { $0.title }) { item in
                            select(item)
                        }
                    } header: {
                        Text("Sport")
                    }
                }

                if sport != .triathlon {
                    Section {
                        Picker("Race format", selection: $isTimed.animation()) {
                            Text("Distance").tag(false)
                            Text("Time").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } footer: {
                        if isTimed {
                            Text("For races with a time limit, such as a 24-hour run: the forecast shows how far you can get.")
                        }
                    }
                }

                if isTimed {
                    timedSections
                } else {
                    distanceSections
                }

                Section {
                    Toggle("Race date is set", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Race date", selection: $raceDay, in: Date.now..., displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("Starting from scratch", isOn: $fromZero)
                } footer: {
                    Text("Volumes then grow more carefully, by 4.5 percent a week instead of 7, with three extra months of buffer.")
                }

                normsSection

                if goal.config != nil {
                    Section {
                        Button("Remove goal", role: .destructive) {
                            goal.clear()
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(goal.config == nil ? "Race goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let draft = draftConfig {
                            goal.save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draftConfig == nil)
                }
            }
            .onChange(of: draftDistance) { previous, current in
                guard !isTimed, let previous, let current else { return }
                if hours * 3600 + minutes * 60 == Int(previous.cutoff) {
                    hours = Int(current.cutoff) / 3600
                    minutes = Int(current.cutoff) % 3600 / 60
                }
            }
            .onChange(of: usesManualNorms) { _, isOn in
                if isOn {
                    fillNorms()
                }
            }
        }
    }

    @ViewBuilder
    private var distanceSections: some View {
        Section {
            ChoiceGrid(items: presetChoices, selection: preset, title: { $0?.title ?? "Other" }) { item in
                preset = item
                if item == nil {
                    fillLegs()
                }
            }
            if preset == nil {
                ForEach(sport.disciplines, id: \.self) { discipline in
                    DistanceField(
                        title: Text(discipline.title),
                        text: binding(\.legTexts, discipline),
                        unit: unit(discipline)
                    )
                }
            }
        } header: {
            Text("Distance")
        } footer: {
            if sport == .triathlon, let distance = draftDistance {
                Text(legs(distance))
            }
        }

        Section {
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(0...maxHours, id: \.self) { value in
                        Text("\(value) hours").tag(value)
                    }
                }
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { value in
                        Text("\(value) minutes").tag(value)
                    }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
        } header: {
            Text("Target finish time")
        } footer: {
            if let distance = draftDistance {
                Text("Cutoff for this distance: \(Formatting.clock(distance.cutoff)). A faster goal raises the target volumes.")
            }
        }
    }

    @ViewBuilder
    private var timedSections: some View {
        Section {
            Picker("Time limit", selection: $timeLimitHours) {
                ForEach([6, 12, 24], id: \.self) { value in
                    Text("\(value) hours").tag(value)
                }
                if ![6, 12, 24].contains(timeLimitHours) {
                    Text("\(timeLimitHours) hours").tag(timeLimitHours)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Stepper(value: $timeLimitHours, in: 1...72) {
                Text("\(timeLimitHours) hours")
                    .font(.system(.body, design: .monospaced))
            }
        } header: {
            Text("Time limit")
        }

        if let discipline = sport.disciplines.first {
            Section {
                Toggle("Distance goal", isOn: $hasGoalDistance.animation())
                if hasGoalDistance {
                    DistanceField(title: Text("Distance"), text: $goalDistanceText, unit: unit(discipline))
                }
            } footer: {
                if hasGoalDistance {
                    Text("The distance you want to cover in this time. It sets the target volumes.")
                } else {
                    Text("Without a distance goal, targets come from the time limit at an easy pace, and the forecast shows how far you can get.")
                }
            }
        }
    }

    private var normsSection: some View {
        Section {
            Toggle("Own volume targets", isOn: $usesManualNorms.animation())
            if usesManualNorms, let distance = draftDistance {
                ForEach(distance.disciplines, id: \.self) { discipline in
                    VStack(alignment: .leading, spacing: 8) {
                        if distance.disciplines.count > 1 {
                            Text(discipline.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.fitness)
                        }
                        DistanceField(title: Text("Per week"), text: binding(\.weeklyTexts, discipline), unit: unit(discipline))
                        DistanceField(title: Text("Longest session"), text: binding(\.longestTexts, discipline), unit: unit(discipline))
                    }
                    .padding(.vertical, 4)
                }
            }
        } footer: {
            Text("For example, from a coach's plan. Without them, targets come from the distance and the target time.")
        }
    }

    private var sports: [Sport] {
        var available = Sport.allCases.filter { profile.isSelected($0) || profile.isIncludedInTriathlon($0) }
        if !available.contains(sport) {
            available.append(sport)
        }
        return available.sorted { $0 == .triathlon && $1 != .triathlon }
    }

    private var presetChoices: [RacePreset?] {
        RacePreset.presets(for: sport).map { Optional($0) } + [nil]
    }

    private var maxHours: Int {
        let cutoffHours = Int(((draftDistance?.cutoff ?? 0) / 3600).rounded(.up)) + 1
        return max(hours, cutoffHours, 1)
    }

    private var draftDistance: RaceDistance? {
        if isTimed {
            guard hasGoalDistance else {
                return RaceDistance(sport: sport, legs: [:])
            }
            guard let discipline = sport.disciplines.first,
                  let meters = unit(discipline).meters(goalDistanceText) else { return nil }
            return RaceDistance(sport: sport, legs: [discipline: meters])
        }
        if let preset {
            return RaceDistance(preset: preset)
        }
        var legs: [Discipline: Double] = [:]
        for discipline in sport.disciplines {
            guard let meters = unit(discipline).meters(legTexts[discipline] ?? "") else { return nil }
            legs[discipline] = meters
        }
        return RaceDistance(sport: sport, legs: legs)
    }

    private var draftConfig: RaceConfig? {
        guard let distance = draftDistance else { return nil }
        var norms: [RaceNorm]?
        if usesManualNorms {
            var list: [RaceNorm] = []
            for discipline in distance.disciplines {
                guard let weekly = unit(discipline).meters(weeklyTexts[discipline] ?? ""),
                      let longest = unit(discipline).meters(longestTexts[discipline] ?? "") else { return nil }
                list.append(RaceNorm(discipline: discipline, weekly: weekly, longest: longest))
            }
            norms = list
        }
        let target = TimeInterval(hours * 3600 + minutes * 60)
        guard isTimed || target > 0 else { return nil }
        return RaceConfig(
            distance: distance,
            raceDay: hasDate ? Calendar.current.startOfDay(for: raceDay) : nil,
            targetTime: isTimed ? nil : target,
            fromZero: fromZero,
            manualNorms: norms,
            timeLimit: isTimed ? TimeInterval(timeLimitHours * 3600) : nil
        )
    }

    private func select(_ item: Sport) {
        guard item != sport else { return }
        sport = item
        preset = Self.defaultPreset(for: item)
        legTexts = [:]
        if item == .triathlon {
            isTimed = false
        }
        let cutoff = Int(RaceDistance(preset: Self.defaultPreset(for: item)).cutoff)
        hours = cutoff / 3600
        minutes = cutoff % 3600 / 60
        weeklyTexts = [:]
        longestTexts = [:]
        if usesManualNorms {
            fillNorms()
        }
    }

    private func fillLegs() {
        let reference = RaceDistance(preset: Self.defaultPreset(for: sport))
        for discipline in sport.disciplines where (legTexts[discipline] ?? "").isEmpty {
            legTexts[discipline] = unit(discipline).text(reference.leg(for: discipline))
        }
    }

    private func fillNorms() {
        guard let distance = draftDistance else { return }
        let draft = RaceConfig(
            distance: distance,
            targetTime: isTimed ? nil : TimeInterval(max(1, hours * 3600 + minutes * 60)),
            timeLimit: isTimed ? TimeInterval(timeLimitHours * 3600) : nil
        )
        for norm in ReadinessCalculator.automaticNorms(for: draft) {
            let unit = unit(norm.discipline)
            if (weeklyTexts[norm.discipline] ?? "").isEmpty {
                weeklyTexts[norm.discipline] = unit.text(norm.weekly)
            }
            if (longestTexts[norm.discipline] ?? "").isEmpty {
                longestTexts[norm.discipline] = unit.text(norm.longest)
            }
        }
    }

    private func unit(_ discipline: Discipline) -> InputUnit {
        InputUnit(discipline: discipline, units: units)
    }

    private func binding(_ path: ReferenceWritableKeyPath<RaceGoalSheet, [Discipline: String]>, _ discipline: Discipline) -> Binding<String> {
        Binding {
            self[keyPath: path][discipline] ?? ""
        } set: {
            self[keyPath: path][discipline] = $0
        }
    }

    private func legs(_ distance: RaceDistance) -> String {
        distance.disciplines
            .map { "\(String(localized: $0.title)) \(Formatting.distance(distance.leg(for: $0), discipline: $0, units: units))" }
            .formatted(.list(type: .and, width: .narrow))
    }

    private static func defaultSport(for profile: SportProfile) -> Sport {
        if profile.isTriathlon {
            return .triathlon
        }
        return Sport.allCases.first { profile.isSelected($0) } ?? .triathlon
    }

    private static func defaultPreset(for sport: Sport) -> RacePreset {
        switch sport {
        case .triathlon: .full
        case .run: .halfMarathon
        case .bike: .bike100
        case .swim: .swim3k
        }
    }
}

private struct ChoiceGrid<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    let title: (Item) -> LocalizedStringResource
    let select: (Item) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.snappy) {
                        select(item)
                    }
                } label: {
                    Text(title(item))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(item == selection ? Palette.background : Palette.text)
                .background(item == selection ? Palette.fitness : Color.white.opacity(0.06), in: Capsule())
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DistanceField: View {
    let title: Text
    @Binding var text: String
    let unit: InputUnit

    var body: some View {
        HStack(spacing: 10) {
            title
                .foregroundStyle(Palette.text)
            Spacer(minLength: 8)
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: 110)
            Text(unit.name)
                .font(.footnote)
                .foregroundStyle(Palette.muted)
        }
    }
}
