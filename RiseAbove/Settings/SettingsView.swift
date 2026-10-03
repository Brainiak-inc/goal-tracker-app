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
    @AppStorage(TextSize.storageKey) private var textSize: TextSize = .standard
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon

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
                    ForEach(profile.disciplines, id: \.self) { discipline in
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
                    TextSizePicker(size: $textSize)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    SettingsHeader("Text size")
                } footer: {
                    Text("Changes the text size in this app on top of the iOS setting. For even larger text: iOS Settings → Accessibility → Display & Text Size.")
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
                        SportsSettingsView()
                    } label: {
                        LabeledContent("Sports") {
                            Text(profile.summary)
                        }
                    }
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

                WorkoutPeriodSection()

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

                Section {
                    Button("Run setup again") {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            UserDefaults.standard.set(false, forKey: OnboardingView.completedKey)
                        }
                    }
                } footer: {
                    Text("Choose your sports, connect Apple Health, and set a goal step by step.")
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

private struct WorkoutPeriodSection: View {
    @Environment(ActivityLibrary.self) private var library

    var body: some View {
        Section {
            Toggle("Only from a chosen date", isOn: isLimited)
            if let since = library.visibleSince {
                LabeledContent {
                    GlassDatePicker(
                        title: "Show workouts from",
                        selection: Binding { since } set: { library.setVisibleSince($0) }
                    )
                } label: {
                    Text("From")
                }
                LabeledContent("Hidden workouts", value: library.hiddenCount, format: .number)
            }
        } header: {
            SettingsHeader("Workout period")
        } footer: {
            Text("Earlier workouts stay in the app and in backups, but they are hidden from lists and left out of calculations: training load, threshold heart rate, and race readiness. For an accurate fitness value, pick a date at least six weeks back.")
        }
        .listRowBackground(Palette.surface)
    }

    private var isLimited: Binding<Bool> {
        Binding {
            library.visibleSince != nil
        } set: { isOn in
            withAnimation(.snappy) {
                library.setVisibleSince(isOn ? defaultStart : nil)
            }
        }
    }

    private var defaultStart: Date {
        library.calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
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
                    if case .failed(let message) = healthSync.status {
                        Text(verbatim: message)
                            .font(.footnote)
                            .foregroundStyle(Palette.fatigue)
                    }
                    Button("Sync now") {
                        Task { await healthSync.sync() }
                    }
                    .disabled(healthSync.isSyncing)
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

            if healthSync.isEnabled {
                Section {
                    Button("Reload all workouts") {
                        Task { await healthSync.reloadAll() }
                    }
                    .disabled(healthSync.isSyncing)
                } footer: {
                    Text("Use this if some workouts from Health are missing. Workouts you deleted in the app won't come back.")
                }
                .listRowBackground(Palette.surface)
            }

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
                    LabeledContent("Workouts in the app", value: library.storedCount, format: .number)
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
    let showsSync: Bool

    @Environment(HealthSync.self) private var healthSync
    @State private var isPresented = false
    @State private var isSyncVisible = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                if showsSync, isSyncVisible {
                    ToolbarItem(placement: .topBarLeading) {
                        ConsoleSpinner(size: 18, lineWidth: 2.2)
                            .frame(width: 36, height: 36)
                            .accessibilityElement()
                            .accessibilityLabel(Text("Syncing with Apple Health"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "person.crop.circle") {
                        isPresented = true
                    }
                }
            }
            .task(id: healthSync.isSyncing) {
                guard healthSync.isSyncing else {
                    isSyncVisible = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(400))
                isSyncVisible = healthSync.isSyncing
            }
            .sheet(isPresented: $isPresented) {
                SettingsView()
            }
    }
}

extension View {
    func settingsToolbar(showsSync: Bool = true) -> some View {
        modifier(SettingsToolbar(showsSync: showsSync))
    }
}
