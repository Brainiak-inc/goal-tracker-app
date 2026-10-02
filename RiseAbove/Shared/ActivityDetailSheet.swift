import SwiftUI
import TrainingKit

struct ActivityDetailSheet: View {
    let activity: Activity

    @Environment(ActivityLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @State private var discipline: Discipline
    @State private var confirmsDeletion = false

    init(activity: Activity) {
        self.activity = activity
        _discipline = State(initialValue: activity.discipline)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date") {
                        Text(activity.start, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Duration") {
                        Text(Duration.seconds(activity.duration), format: .units(allowed: [.hours, .minutes], width: .wide))
                    }
                    if let distance = activity.distance, distance > 0 {
                        LabeledContent("Distance", value: Formatting.distance(distance, discipline: activity.discipline, units: units))
                        if let pace = Formatting.pace(distance: distance, duration: activity.duration, discipline: activity.discipline, units: units) {
                            LabeledContent(activity.discipline == .bike ? "Speed" : "Pace", value: pace)
                        }
                    }
                    if let heartRate = activity.averageHeartRate {
                        LabeledContent("Average heart rate") {
                            Text("\(heartRate.displayRounded) bpm")
                        }
                    }
                    if let heartRate = activity.maxHeartRate {
                        LabeledContent("Max heart rate") {
                            Text("\(heartRate.displayRounded) bpm")
                        }
                    }
                    if let calories = activity.calories {
                        LabeledContent("Calories") {
                            Text("\(calories.displayRounded) kcal")
                        }
                    }
                    LabeledContent("Load (TSS)", value: library.stress(for: activity), format: .number.precision(.fractionLength(0)))
                    LabeledContent("Source") {
                        if activity.externalID != nil {
                            Text("Apple Health")
                        } else {
                            Text("Import · \(activity.sourceType)")
                        }
                    }
                }
                .listRowBackground(Palette.surface)

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Discipline.allCases, id: \.self) { item in
                            Button {
                                discipline = item
                            } label: {
                                Text(item.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.consoleChip(isActive: item == discipline))
                            .accessibilityAddTraits(item == discipline ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    SettingsHeader("Discipline")
                } footer: {
                    Text("Fix the discipline if the import guessed it wrong. The change survives re-imports.")
                }
                .listRowBackground(Palette.surface)

                Section {
                    Button("Delete workout", role: .destructive) {
                        confirmsDeletion = true
                    }
                } footer: {
                    Text("A deleted workout won't come back with the next import or sync.")
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(activity.title.isEmpty ? String(localized: activity.discipline.title) : activity.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if discipline != activity.discipline {
                            library.setDiscipline(discipline, for: activity.identity)
                        }
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete this workout?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    library.delete(activity.identity)
                    dismiss()
                }
            }
        }
    }
}
