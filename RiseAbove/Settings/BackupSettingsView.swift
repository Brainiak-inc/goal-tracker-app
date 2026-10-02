import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @Environment(BackupManager.self) private var backup
    @State private var exports = false
    @State private var picksFolder = false

    var body: some View {
        List {
            Section {
                BackupContentRow(title: "Workouts", detail: "From Health and CSV imports, with heart rate", systemImage: "figure.run")
                BackupContentRow(title: "Training plans", detail: "Weeks, workouts, notes, and ticks", systemImage: "calendar")
                BackupContentRow(title: "Race goal", detail: "Distance, date, and target time", systemImage: "scope")
                BackupContentRow(title: "Adherence calendar", detail: "Day marks and comments", systemImage: "calendar.badge.checkmark")
                BackupContentRow(title: "Settings", detail: "Threshold heart rate, units, and plan ticking", systemImage: "gearshape")
            } header: {
                SettingsHeader("What a backup contains")
            } footer: {
                Text("Manual and automatic backups contain the same data. The file is compatible with the web version.")
            }
            .listRowBackground(Palette.surface)

            Section {
                Button {
                    exports = true
                } label: {
                    Label("Save backup now", systemImage: "square.and.arrow.down.on.square")
                }
                LabeledContent("Last backup") {
                    BackupStatusText()
                }
                ShareLink(item: BackupFile(data: backup.document.data, name: "\(backup.suggestedFileName).json"), preview: SharePreview(Text("\(AppInfo.name) backup"))) {
                    Label("Send backup", systemImage: "square.and.arrow.up")
                }
            } header: {
                SettingsHeader("Manual")
            } footer: {
                Text("Save the file to Files, for example to iCloud Drive, or send it to your Mac.")
            }
            .listRowBackground(Palette.surface)

            Section {
                Toggle("Automatic backup", isOn: Binding(
                    get: { backup.isAutoEnabled },
                    set: { isOn in
                        if isOn {
                            picksFolder = true
                        } else {
                            backup.disableAutomaticBackup()
                        }
                    }
                ))
                if backup.isAutoEnabled {
                    LabeledContent("Folder", value: backup.folderName ?? "")
                    Button("Change folder") {
                        picksFolder = true
                    }
                    if case .failed(let message) = backup.status {
                        Text(verbatim: message)
                            .font(.footnote)
                            .foregroundStyle(Palette.danger)
                    }
                }
            } header: {
                SettingsHeader("Automatic")
            } footer: {
                Text("After every change the app updates “\(BackupManager.fileName)” in the folder you choose. Choose a folder in iCloud Drive to restore your data after reinstalling the app or on a new iPhone.")
            }
            .listRowBackground(Palette.surface)

            Section {
                WebBackupImportButton(title: "Restore from backup")
            } header: {
                SettingsHeader("Restore")
            } footer: {
                Text("Pick a backup file. Its data is merged with what's already in the app, without duplicates.")
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exports, document: backup.document, contentType: .json, defaultFilename: backup.suggestedFileName) { result in
            if case .success = result {
                backup.recordBackup()
            }
        }
        .fileImporter(isPresented: $picksFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result {
                backup.enableAutomaticBackup(in: folder)
            }
        }
    }
}

private struct BackupContentRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.fitness)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct BackupStatusText: View {
    @Environment(BackupManager.self) private var backup

    var body: some View {
        Group {
            if backup.status == .writing {
                HStack(spacing: 6) {
                    ConsoleSpinner(size: 11, lineWidth: 1.6)
                    Text("Saving…")
                }
            } else if let date = backup.lastBackup {
                Text(date, format: .relative(presentation: .named))
            } else {
                Text("Never")
            }
        }
        .foregroundStyle(backup.isStale ? Palette.fatigue : Palette.muted)
    }
}

struct BackupReminderCard: View {
    @Environment(BackupManager.self) private var backup
    @State private var exports = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Save a backup", systemImage: "externaldrive.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(Palette.fatigue)
            Text("Your plans live only on this iPhone. Save a copy to Files or turn on automatic backup in Settings.")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Save") {
                    exports = true
                }
                .buttonStyle(.consolePrimary)
                Button("Later") {
                    withAnimation(.snappy) {
                        backup.snoozeReminder()
                    }
                }
                .buttonStyle(.consoleSecondary)
            }
        }
        .padding(16)
        .consoleCard(brackets: false)
        .fileExporter(isPresented: $exports, document: backup.document, contentType: .json, defaultFilename: backup.suggestedFileName) { result in
            if case .success = result {
                backup.recordBackup()
            }
        }
    }
}
