import SwiftUI
import TrainingKit

struct CreatePlanSheet: View {
    @Environment(PlanStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    @State private var name = ""
    @State private var isDated = true
    @State private var start = Date.now
    @State private var weeks = 12

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Base season", text: $name)
                }
                Section {
                    Toggle("Tie to dates", isOn: $isDated.animation())
                    if isDated {
                        DatePicker("Start", selection: $start, displayedComponents: .date)
                    }
                } footer: {
                    if isDated {
                        Text("Weeks start on Monday, \(calendar.monday(of: start).formatted(.dateTime.day().month(.wide))).")
                    } else {
                        Text("Weeks are numbered without dates. Plan and actual volume are compared only for dated plans.")
                    }
                }
                Section {
                    Stepper(value: $weeks, in: 1...52) {
                        Text("\(weeks) weeks")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("New plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        plans.perform {
                            $0.createPlan(
                                name: trimmed.isEmpty ? String(localized: "Training plan") : trimmed,
                                startingOn: isDated ? start : nil,
                                weeks: weeks,
                                calendar: calendar
                            )
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
