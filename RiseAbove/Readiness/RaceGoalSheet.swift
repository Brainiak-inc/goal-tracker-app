import SwiftUI
import TrainingKit

struct RaceGoalSheet: View {
    @Environment(RaceGoalStore.self) private var goal
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    @State private var distance: RaceDistance
    @State private var hasDate: Bool
    @State private var raceDay: Date
    @State private var hours: Int
    @State private var minutes: Int
    @State private var fromZero: Bool

    init(config: RaceConfig?) {
        let distance = config?.distance ?? .full
        let target = Int(config?.targetTime ?? distance.cutoff)
        _distance = State(initialValue: distance)
        _hasDate = State(initialValue: config?.raceDay != nil)
        _raceDay = State(initialValue: config?.raceDay ?? Calendar.current.date(byAdding: .month, value: 9, to: .now) ?? .now)
        _hours = State(initialValue: target / 3600)
        _minutes = State(initialValue: (target % 3600) / 60 / 5 * 5)
        _fromZero = State(initialValue: config?.fromZero ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Distance", selection: $distance) {
                        Text("Full distance").tag(RaceDistance.full)
                        Text("Half distance").tag(RaceDistance.half)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(legs)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                } header: {
                    Text("Distance")
                }

                Section {
                    Toggle("Race date is set", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Race date", selection: $raceDay, in: Date.now..., displayedComponents: .date)
                    }
                }

                Section {
                    HStack(spacing: 0) {
                        Picker("Hours", selection: $hours) {
                            ForEach(3...17, id: \.self) { value in
                                Text("\(value) hours").tag(value)
                            }
                        }
                        Picker("Minutes", selection: $minutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { value in
                                Text("\(value) minutes").tag(value)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                } header: {
                    Text("Target finish time")
                } footer: {
                    Text("The cutoff is 17 hours for the full distance and 8 hours 30 minutes for the half. A faster goal raises the target volumes.")
                }

                Section {
                    Toggle("Starting from scratch", isOn: $fromZero)
                } footer: {
                    Text("Volumes then grow more carefully, by 4.5 percent a week instead of 7, with three extra months of buffer.")
                }

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
                        goal.save(RaceConfig(
                            distance: distance,
                            raceDay: hasDate ? Calendar.current.startOfDay(for: raceDay) : nil,
                            targetTime: TimeInterval(hours * 3600 + minutes * 60),
                            fromZero: fromZero
                        ))
                        dismiss()
                    }
                }
            }
            .onChange(of: distance) { previous, current in
                if hours * 3600 + minutes * 60 == Int(previous.cutoff) {
                    hours = Int(current.cutoff) / 3600
                    minutes = Int(current.cutoff) % 3600 / 60
                }
            }
        }
    }

    private var legs: String {
        Discipline.triathlon
            .map { "\(String(localized: $0.title)) \(Formatting.distance(distance.leg(for: $0), discipline: $0, units: units))" }
            .formatted(.list(type: .and, width: .narrow))
    }
}
