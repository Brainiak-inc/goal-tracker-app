import SwiftUI
import TrainingKit

struct SettingsView: View {
    @Environment(ActivityLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @State private var confirmsDeletion = false

    var body: some View {
        NavigationStack {
            List {
                Section("Units") {
                    Picker("Units", selection: $units) {
                        ForEach(UnitSystem.allCases) { system in
                            Text(system.title).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    ForEach(Discipline.triathlon, id: \.self) { discipline in
                        LabeledContent {
                            Text(unitsDescription(discipline))
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(discipline.title)
                        }
                    }
                }
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        LabeledContent("App language", value: currentLanguage)
                            .foregroundStyle(Palette.text)
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("Opens iOS Settings for this app.")
                }
                Section("Data") {
                    GarminImportButton()
                    NavigationLink("Apple Health check") {
                        HealthDiagnosticsView()
                    }
                    if library.hasData {
                        LabeledContent("Imported workouts", value: library.activities.count, format: .number)
                        Button("Delete imported data", role: .destructive) {
                            confirmsDeletion = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete imported data?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    library.removeAll()
                }
            } message: {
                Text("Imported workouts will be removed from this iPhone. Your Health data stays as it is.")
            }
        }
    }
}

private extension SettingsView {
    var currentLanguage: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.current.localizedString(forLanguageCode: code)?.capitalized(with: .current) ?? code
    }

    func unitsDescription(_ discipline: Discipline) -> LocalizedStringResource {
        switch (discipline, units) {
        case (.swim, .metric): "meters, pace per 100 m"
        case (.swim, .imperial): "yards, pace per 100 yd"
        case (.bike, .metric): "kilometers, km/h"
        case (.bike, .imperial): "miles, mph"
        case (_, .metric): "kilometers, pace per km"
        case (_, .imperial): "miles, pace per mile"
        }
    }
}

private struct SettingsToolbar: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "person.crop.circle") {
                        isPresented = true
                    }
                }
            }
            .sheet(isPresented: $isPresented) {
                SettingsView()
            }
    }
}

extension View {
    func settingsToolbar() -> some View {
        modifier(SettingsToolbar())
    }
}
