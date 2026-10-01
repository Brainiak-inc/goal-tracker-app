import Foundation
import Observation
import SwiftUI
import TrainingKit
import UniformTypeIdentifiers

@Observable
final class BackupManager {
    enum Status: Equatable {
        case idle
        case writing
        case failed(String)
    }

    private enum Keys {
        static let lastBackup = "backupLastDate"
        static let autoEnabled = "backupAutoEnabled"
        static let folder = "backupFolderBookmark"
        static let folderName = "backupFolderName"
        static let snoozedUntil = "backupReminderSnoozedUntil"
    }

    nonisolated static var fileName: String { "\(AppInfo.name).json" }
    static let reminderInterval: TimeInterval = 14 * 24 * 3600

    private(set) var lastBackup: Date?
    private(set) var isAutoEnabled: Bool
    private(set) var folderName: String?
    private(set) var status: Status = .idle
    private(set) var snoozedUntil: Date?

    @ObservationIgnored private let library: ActivityLibrary
    @ObservationIgnored private let plans: PlanStore
    @ObservationIgnored private let raceGoal: RaceGoalStore
    @ObservationIgnored private let adherence: AdherenceStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var hasChanges = false

    init(library: ActivityLibrary, plans: PlanStore, raceGoal: RaceGoalStore, adherence: AdherenceStore, defaults: UserDefaults = .standard) {
        self.library = library
        self.plans = plans
        self.raceGoal = raceGoal
        self.adherence = adherence
        self.defaults = defaults
        lastBackup = defaults.object(forKey: Keys.lastBackup) as? Date
        isAutoEnabled = defaults.bool(forKey: Keys.autoEnabled) && defaults.data(forKey: Keys.folder) != nil
        folderName = defaults.string(forKey: Keys.folderName)
        snoozedUntil = defaults.object(forKey: Keys.snoozedUntil) as? Date
    }

    var isStale: Bool {
        guard let lastBackup else { return true }
        return Date.now.timeIntervalSince(lastBackup) > Self.reminderInterval
    }

    var needsReminder: Bool {
        guard !isAutoEnabled, !plans.book.plans.isEmpty, isStale else { return false }
        return snoozedUntil.map { $0 < .now } ?? true
    }

    var document: BackupDocument {
        BackupDocument(data: (try? makeBackup()) ?? Data())
    }

    var suggestedFileName: String {
        "\(AppInfo.name) \(Date.now.formatted(.iso8601.year().month().day()))"
    }

    func makeBackup() throws -> Data {
        try library.exportBackup(
            plans: plans.book.plans,
            raceConfig: raceGoal.config,
            adherence: adherence.book,
            preferences: Self.preferences(defaults)
        )
    }

    func recordBackup() {
        lastBackup = .now
        defaults.set(lastBackup, forKey: Keys.lastBackup)
    }

    func snoozeReminder() {
        snoozedUntil = Date.now.addingTimeInterval(Self.reminderInterval)
        defaults.set(snoozedUntil, forKey: Keys.snoozedUntil)
    }

    @discardableResult
    func enableAutomaticBackup(in folder: URL) -> Bool {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        guard let bookmark = try? folder.bookmarkData() else {
            status = .failed(String(localized: "Couldn't get access to this folder."))
            return false
        }
        defaults.set(bookmark, forKey: Keys.folder)
        folderName = Self.displayName(of: folder)
        defaults.set(folderName, forKey: Keys.folderName)
        isAutoEnabled = true
        defaults.set(true, forKey: Keys.autoEnabled)
        hasChanges = true
        scheduleAutomaticBackup(after: .zero)
        return true
    }

    func disableAutomaticBackup() {
        pending?.cancel()
        isAutoEnabled = false
        status = .idle
        defaults.set(false, forKey: Keys.autoEnabled)
    }

    func dataDidChange() {
        guard isAutoEnabled else { return }
        hasChanges = true
        scheduleAutomaticBackup(after: .seconds(3))
    }

    func flush() async {
        guard isAutoEnabled, hasChanges else { return }
        pending?.cancel()
        await writeAutomaticBackup()
    }

    private func scheduleAutomaticBackup(after delay: Duration) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.writeAutomaticBackup()
        }
    }

    private func writeAutomaticBackup() async {
        guard isAutoEnabled, let bookmark = defaults.data(forKey: Keys.folder) else { return }
        status = .writing
        do {
            var isStale = false
            let folder = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            let data = try makeBackup()
            let renewed = try await Task.detached {
                try Self.write(data, into: folder, renewBookmark: isStale)
            }.value
            if let renewed {
                defaults.set(renewed, forKey: Keys.folder)
            }
            hasChanges = false
            recordBackup()
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    nonisolated private static func write(_ data: Data, into folder: URL, renewBookmark: Bool) throws -> Data? {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        let file = folder.appending(path: fileName)
        var coordinationError: NSError?
        var writeError: (any Error)?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &coordinationError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError {
            throw error
        }
        return renewBookmark ? try? folder.bookmarkData() : nil
    }

    static func preferences(_ defaults: UserDefaults) -> [String: String] {
        [
            UnitSystem.storageKey: defaults.string(forKey: UnitSystem.storageKey) ?? UnitSystem.metric.rawValue,
            PlanStore.autoCheckKey: (defaults.object(forKey: PlanStore.autoCheckKey) as? Bool ?? true) ? "true" : "false"
        ]
    }

    static func apply(_ preferences: [String: String], to defaults: UserDefaults) {
        if let units = preferences[UnitSystem.storageKey], UnitSystem(rawValue: units) != nil {
            defaults.set(units, forKey: UnitSystem.storageKey)
        }
        if let autoCheck = preferences[PlanStore.autoCheckKey] {
            defaults.set(autoCheck == "true", forKey: PlanStore.autoCheckKey)
        }
    }

    private static func displayName(of folder: URL) -> String {
        let path = folder.path(percentEncoded: false)
        let name = FileManager.default.displayName(atPath: path)
        if path.contains("com~apple~CloudDocs"), !name.contains("iCloud") {
            return "iCloud Drive › \(name)"
        }
        return name
    }
}

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
