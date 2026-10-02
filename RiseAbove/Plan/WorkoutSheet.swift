import SwiftUI
import TrainingKit

struct WorkoutDraft: Identifiable {
    let id = UUID()
    var weekID: UUID
    var day: Int
    var workout: PlannedWorkout
    var isNew: Bool
}

struct WorkoutSheet: View {
    let plan: TrainingPlan
    let draft: WorkoutDraft

    @Environment(PlanStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric

    @State private var weekID: UUID
    @State private var day: Int
    @State private var discipline: Discipline
    @State private var distanceText: String
    @State private var title: String
    @State private var note: String
    @State private var distanceIsInvalid = false

    init(plan: TrainingPlan, draft: WorkoutDraft) {
        self.plan = plan
        self.draft = draft
        _weekID = State(initialValue: draft.weekID)
        _day = State(initialValue: draft.day)
        _discipline = State(initialValue: draft.workout.discipline)
        _distanceText = State(initialValue: "")
        _title = State(initialValue: draft.workout.title)
        _note = State(initialValue: draft.workout.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if plan.weeks.count > 1 {
                        Picker("Week", selection: $weekID) {
                            ForEach(Array(plan.weeks.enumerated()), id: \.element.id) { index, week in
                                Text(plan.weekTitle(index, calendar: calendar)).tag(week.id)
                            }
                        }
                    }
                    Picker("Day", selection: $day) {
                        ForEach(0..<PlanWeek.dayCount, id: \.self) { day in
                            Text(plan.dayTitle(day, ofWeek: weekIndex, calendar: calendar)).tag(day)
                        }
                    }
                }

                Section("Discipline") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Discipline.allCases, id: \.self) { item in
                            Button {
                                discipline = item
                            } label: {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(item == discipline ? Palette.background : Palette.text)
                            .background(item == discipline ? Palette.fitness : Color.white.opacity(0.06), in: Capsule())
                            .accessibilityAddTraits(item == discipline ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                if discipline.isTriathlon {
                    Section {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            TextField("0", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                                .onChange(of: distanceText) { distanceIsInvalid = false }
                            Text(unitName)
                                .foregroundStyle(Palette.fitness)
                        }
                        if distanceIsInvalid {
                            Text("Enter a number, for example 10 or 7.5")
                                .font(.footnote)
                                .foregroundStyle(Palette.fatigue)
                        }
                    } header: {
                        Text("Distance")
                    } footer: {
                        Text("Leave empty if the workout is planned by time.")
                    }
                }

                Section("Details · optional") {
                    TextField("Title, for example tempo run", text: $title)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                if !draft.isNew {
                    Section {
                        Button("Delete workout", role: .destructive) {
                            plans.perform { $0.removeWorkout(draft.workout.id, from: plan.id) }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(draft.isNew ? "New workout" : "Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    }
                }
            }
            .onAppear {
                if distanceText.isEmpty, let meters = draft.workout.distance {
                    distanceText = Self.format(meters / unitFactor)
                }
            }
        }
    }

    private var weekIndex: Int {
        plan.weeks.firstIndex { $0.id == weekID } ?? 0
    }

    private var unitFactor: Double {
        switch (discipline == .swim, units) {
        case (true, .metric): 1
        case (true, .imperial): 0.9144
        case (false, .metric): 1000
        case (false, .imperial): 1609.344
        }
    }

    private var unitName: String {
        let unit: UnitLength = switch (discipline == .swim, units) {
        case (true, .metric): .meters
        case (true, .imperial): .yards
        case (false, .metric): .kilometers
        case (false, .imperial): .miles
        }
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .long
        return formatter.string(from: unit)
    }

    private func save() {
        var distance: Double?
        let trimmed = distanceText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if discipline.isTriathlon, !trimmed.isEmpty {
            guard let value = Double(trimmed), value > 0 else {
                distanceIsInvalid = true
                return
            }
            distance = value * unitFactor
        }
        var workout = draft.workout
        workout.discipline = discipline
        workout.distance = distance
        workout.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        plans.perform { $0.save(workout, in: plan.id, week: weekID, day: day) }
        dismiss()
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
