import Foundation
import Observation
import TrainingKit

struct ImportSummary: Hashable {
    let added: Int
    let updated: Int
    let skipped: Int
}

@Observable
final class ActivityLibrary {
    static let sinceKey = "activitiesSince"

    private struct Stored: Codable {
        var activities: [Activity]
        var settings: AthleteSettings
        var thresholdIsManual: Bool
        var deleted: Set<String>
    }

    private(set) var activities: [Activity] = []
    private(set) var settings = AthleteSettings()
    private(set) var series: [LoadPoint] = []
    private(set) var thresholdIsManual = false
    private(set) var visibleSince: Date?
    private(set) var revision = 0
    private var stored: [Activity] = []
    private var deleted: Set<String> = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let defaults: UserDefaults

    init(
        fileURL: URL = URL.applicationSupportDirectory.appending(path: "library.json"),
        defaults: UserDefaults = .standard
    ) {
        self.fileURL = fileURL
        self.defaults = defaults
        load()
    }

    var calendar: Calendar { .current }

    var hasData: Bool { !stored.isEmpty }

    var storedCount: Int { stored.count }

    var hiddenCount: Int { stored.count - activities.count }

    var fitness: FitnessSnapshot? { FitnessSnapshot(series: series) }

    var fitnessTrend: (trend: Trend, delta: Double)? { Trend.fitness(series) }

    var weeklyStress: Double { series.suffix(7).reduce(0) { $0 + $1.stress } }

    var recent: [Activity] { Array(activities.reversed()) }

    func activities(for discipline: Discipline) -> [Activity] {
        activities.filter { $0.discipline == discipline }
    }

    func series(for discipline: Discipline) -> [LoadPoint] {
        TrainingLoad.series(activities, settings: settings, calendar: calendar) { $0.discipline == discipline }
    }

    func weeklyVolume(_ discipline: Discipline, weeks: Int = 10) -> [Double] {
        WeeklyVolume.series(activities, discipline: discipline, weeks: weeks, now: .now, calendar: calendar, includingCurrent: true)
    }

    func weekStarts(_ weeks: Int = 10) -> [Date] {
        WeeklyVolume.weekStarts(weeks: weeks, now: .now, calendar: calendar, includingCurrent: true)
    }

    func stress(for activity: Activity) -> Double {
        TrainingLoad.heartRateStress(activity, settings: settings)
    }

    func importGarminCSV(_ text: String) -> ImportSummary {
        let parsed = GarminCSV.parse(text)
        let merged = ActivityMerge.merge(stored, with: parsed.activities, excluding: deleted)
        stored = merged.activities
        refresh()
        return ImportSummary(added: merged.added, updated: merged.updated, skipped: parsed.skipped)
    }

    @discardableResult
    func applyHealthChanges(added: [Activity], deletedIDs: Set<String>) -> Int {
        let kept = ActivityMerge.removing(externalIDs: deletedIDs, from: stored)
        let merged = ActivityMerge.merge(kept, with: added, excluding: deleted)
        guard merged.activities != stored else { return 0 }
        stored = merged.activities
        refresh()
        return merged.added
    }

    func importBackup(_ backup: WebBackup) -> Int {
        deleted.formUnion(backup.deleted)
        let merged = ActivityMerge.merge(stored, with: backup.activities, excluding: deleted)
        stored = merged.activities
        if let imported = backup.settings {
            settings = imported
            thresholdIsManual = backup.thresholdIsManual
        }
        if let since = backup.preferences[Self.sinceKey] {
            visibleSince = Self.day(from: since, calendar: calendar)
            storeVisibleSince()
        }
        refresh()
        return merged.added
    }

    func exportBackup(plans: [TrainingPlan], raceConfig: RaceConfig?, adherence: AdherenceBook, preferences: [String: String]) throws -> Data {
        try WebBackup.export(
            activities: stored,
            deleted: deleted,
            settings: settings,
            thresholdIsManual: thresholdIsManual,
            plans: plans,
            raceConfig: raceConfig,
            adherence: adherence,
            preferences: preferences,
            calendar: calendar,
            now: .now
        )
    }

    var thresholdEstimate: Double? {
        TrainingLoad.estimateThresholdHeartRate(activities, discipline: .run)
    }

    func setThreshold(manual value: Double?) {
        if let value {
            thresholdIsManual = true
            settings.thresholdHeartRate = value
        } else {
            thresholdIsManual = false
            settings.thresholdHeartRate = thresholdEstimate ?? AthleteSettings.fallbackThresholdHeartRate
        }
        refresh()
    }

    func setVisibleSince(_ date: Date?) {
        let day = date.map { calendar.startOfDay(for: $0) }
        guard day != visibleSince else { return }
        visibleSince = day
        storeVisibleSince()
        refresh()
    }

    func setDiscipline(_ discipline: Discipline, for identity: String) {
        guard let index = stored.firstIndex(where: { $0.identity == identity }) else { return }
        stored[index].discipline = discipline
        refresh()
    }

    func delete(_ identity: String) {
        stored.removeAll { $0.identity == identity }
        deleted.insert(identity)
        refresh()
    }

    func removeAll() {
        stored = []
        settings = AthleteSettings()
        thresholdIsManual = false
        deleted = []
        refresh()
    }

    private func refresh() {
        activities = visible(stored)
        if !thresholdIsManual, let estimate = thresholdEstimate {
            settings.thresholdHeartRate = estimate
        }
        series = TrainingLoad.series(activities, settings: settings, calendar: calendar)
        revision += 1
        save()
    }

    private func visible(_ all: [Activity]) -> [Activity] {
        guard let visibleSince else { return all }
        return all.filter { $0.start >= visibleSince }
    }

    private func storeVisibleSince() {
        if let visibleSince {
            defaults.set(Self.dayString(visibleSince, calendar: calendar), forKey: Self.sinceKey)
        } else {
            defaults.removeObject(forKey: Self.sinceKey)
        }
    }

    private func load() {
        visibleSince = defaults.string(forKey: Self.sinceKey).flatMap { Self.day(from: $0, calendar: calendar) }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        stored = decoded.activities
        settings = decoded.settings
        thresholdIsManual = decoded.thresholdIsManual
        deleted = decoded.deleted
        activities = visible(stored)
        series = TrainingLoad.series(activities, settings: settings, calendar: calendar)
    }

    private func save() {
        let snapshot = Stored(activities: stored, settings: settings, thresholdIsManual: thresholdIsManual, deleted: deleted)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Saving the library failed: \(error)")
        }
    }

    private static func dayFormat(_ calendar: Calendar) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
    }

    private static func dayString(_ date: Date, calendar: Calendar) -> String {
        date.formatted(dayFormat(calendar))
    }

    private static func day(from string: String, calendar: Calendar) -> Date? {
        try? Date(string, strategy: dayFormat(calendar))
    }
}
