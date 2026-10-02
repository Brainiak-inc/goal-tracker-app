import SwiftUI
import TrainingKit
import UniformTypeIdentifiers

struct WebBackupImportButton: View {
    var title: LocalizedStringKey = "Import backup"

    struct Summary {
        let workouts: Int
        let plans: Int
        let raceGoal: Bool
        let calendarMarks: Bool
    }

    @Environment(ActivityLibrary.self) private var library
    @Environment(PlanStore.self) private var plans
    @Environment(RaceGoalStore.self) private var raceGoal
    @Environment(AdherenceStore.self) private var adherence
    @Environment(\.calendar) private var calendar
    @State private var isPicking = false
    @State private var summary: Summary?
    @State private var failed = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Label(title, systemImage: "arrow.down.doc")
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result,
                  let data = read(url),
                  let backup = try? WebBackup(data: data, calendar: calendar) else {
                failed = true
                return
            }
            let workouts = library.importBackup(backup)
            var importedPlans = 0
            plans.perform { importedPlans = $0.importPlans(backup.plans) }
            if let config = backup.raceConfig {
                raceGoal.save(config)
            }
            if !backup.adherence.isEmpty {
                adherence.perform { $0.merge(backup.adherence) }
            }
            BackupManager.apply(backup.preferences, to: .standard)
            summary = Summary(
                workouts: workouts,
                plans: importedPlans,
                raceGoal: backup.raceConfig != nil,
                calendarMarks: !backup.adherence.isEmpty
            )
        }
        .alert("Backup imported", isPresented: Binding(get: { summary != nil }, set: { if !$0 { summary = nil } }), presenting: summary) { _ in
            Button("OK") {}
        } message: { summary in
            Text(message(summary))
        }
        .alert("Couldn't read the backup", isPresented: $failed) {
            Button("OK") {}
        } message: {
            Text("Choose the JSON file saved from the web version: Menu → Export data.")
        }
    }

    private func message(_ summary: Summary) -> String {
        var lines = [
            String(localized: "New workouts: \(summary.workouts)"),
            String(localized: "New plans: \(summary.plans)")
        ]
        if summary.raceGoal {
            lines.append(String(localized: "The race goal was carried over."))
        }
        if summary.calendarMarks {
            lines.append(String(localized: "The adherence calendar was carried over."))
        }
        return lines.joined(separator: "\n")
    }

    private func read(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? Data(contentsOf: url)
    }
}
