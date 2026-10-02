import SwiftUI
import TrainingKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ActivityLibrary.self) private var library
    @Environment(HealthSync.self) private var healthSync
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @AppStorage(PlanStore.autoCheckKey) private var autoCheck = true

    var body: some View {
        NavigationStack {
            List {
                Section {
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
                } header: {
                    SettingsHeader("Units")
                }
                .listRowBackground(Palette.surface)

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
                    SettingsHeader("Language")
                } footer: {
                    Text("Opens iOS Settings for this app.")
                }
                .listRowBackground(Palette.surface)

                Section {
                    NavigationLink {
                        ThresholdView()
                    } label: {
                        LabeledContent("Threshold heart rate") {
                            Text("\(library.settings.thresholdHeartRate.displayRounded) bpm")
                        }
                    }
                } header: {
                    SettingsHeader("Training")
                } footer: {
                    Text("Training load is calculated from heart rate relative to this threshold.")
                }
                .listRowBackground(Palette.surface)

                Section {
                    Toggle("Tick off days from actual workouts", isOn: $autoCheck)
                } header: {
                    SettingsHeader("Plan")
                } footer: {
                    Text("A day in a dated plan is marked done when workouts from Health or an import cover at least 80% of the planned distance. If you untick a day yourself, it stays unticked.")
                }
                .listRowBackground(Palette.surface)

                Section {
                    NavigationLink {
                        HealthSettingsView()
                    } label: {
                        LabeledContent("Apple Health") {
                            if healthSync.isEnabled {
                                Text("Connected")
                                    .foregroundStyle(Palette.success)
                            } else {
                                Text("Not connected")
                            }
                        }
                    }
                    NavigationLink {
                        ImportDataView()
                    } label: {
                        LabeledContent("Import from file", value: String(localized: "CSV, backup"))
                    }
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        LabeledContent("Backup") {
                            BackupStatusText()
                        }
                    }
                } header: {
                    SettingsHeader("Data")
                }
                .listRowBackground(Palette.surface)
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

struct SettingsHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .consoleLabel()
    }
}

struct BackupFile: Transferable {
    let data: Data
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let url = URL.temporaryDirectory.appending(path: file.name)
            try file.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct HealthSettingsView: View {
    @Environment(HealthSync.self) private var healthSync

    var body: some View {
        List {
            Section {
                if healthSync.isEnabled {
                    LabeledContent("Status") {
                        HealthSyncStatus()
                    }
                    Button("Sync now") {
                        Task { await healthSync.sync() }
                    }
                    Button("Disconnect", role: .destructive) {
                        healthSync.disable()
                    }
                } else {
                    HealthConnectButton()
                }
            } footer: {
                if healthSync.isEnabled {
                    Text("New workouts arrive automatically, even when the app is closed. Disconnecting keeps the workouts already synced.")
                } else {
                    Text("Workouts from Garmin Connect, Strava, and other apps that write to Health will appear automatically.")
                }
            }
            .listRowBackground(Palette.surface)

            Section {
                NavigationLink("Health data check") {
                    HealthDiagnosticsView()
                }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ImportDataView: View {
    @Environment(ActivityLibrary.self) private var library
    @State private var confirmsDeletion = false

    var body: some View {
        List {
            Section {
                GarminImportButton()
            } footer: {
                Text("In Garmin Connect: Activities → Export CSV.")
            }
            .listRowBackground(Palette.surface)

            Section {
                WebBackupImportButton()
            } footer: {
                Text("A file saved from the web version (Menu → Export data) or from this app.")
            }
            .listRowBackground(Palette.surface)

            if library.hasData {
                Section {
                    LabeledContent("Workouts in the app", value: library.activities.count, format: .number)
                    Button("Delete imported data", role: .destructive) {
                        confirmsDeletion = true
                    }
                }
                .listRowBackground(Palette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Import from file")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete imported data?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.removeAll()
            }
        } message: {
            Text("Imported workouts will be removed from this iPhone. Your Health data stays as it is.")
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
