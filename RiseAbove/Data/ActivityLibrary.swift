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
    private var deleted: Set<String> = []

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "library.json")) {
        self.fileURL = fileURL
        load()
    }

    var calendar: Calendar { .current }

    var hasData: Bool { !activities.isEmpty }

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
        WeeklyVolume.series(activities, discipline: discipline, weeks: weeks, now: .now, calendar: calendar)
    }

    func stress(for activity: Activity) -> Double {
        TrainingLoad.heartRateStress(activity, settings: settings)
    }

    func importGarminCSV(_ text: String) -> ImportSummary {
        let parsed = GarminCSV.parse(text)
        let merged = ActivityMerge.merge(activities, with: parsed.activities, excluding: deleted)
        activities = merged.activities
        updateThreshold()
        refresh()
        return ImportSummary(added: merged.added, updated: merged.updated, skipped: parsed.skipped)
    }

    @discardableResult
    func applyHealthChanges(added: [Activity], deletedIDs: Set<String>) -> Int {
        let kept = ActivityMerge.removing(externalIDs: deletedIDs, from: activities)
        let merged = ActivityMerge.merge(kept, with: added, excluding: deleted)
        guard merged.activities != activities else { return 0 }
        activities = merged.activities
        updateThreshold()
        refresh()
        return merged.added
    }

    func importBackup(_ backup: WebBackup) -> Int {
        deleted.formUnion(backup.deleted)
        let merged = ActivityMerge.merge(activities, with: backup.activities, excluding: deleted)
        activities = merged.activities
        if let imported = backup.settings {
            settings = imported
            thresholdIsManual = backup.thresholdIsManual
        }
        updateThreshold()
        refresh()
        return merged.added
    }

    func exportBackup(plans: [TrainingPlan], raceConfig: RaceConfig?, adherence: AdherenceBook, preferences: [String: String]) throws -> Data {
        try WebBackup.export(
            activities: activities,
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

    func setDiscipline(_ discipline: Discipline, for identity: String) {
        guard let index = activities.firstIndex(where: { $0.identity == identity }) else { return }
        activities[index].discipline = discipline
        updateThreshold()
        refresh()
    }

    func delete(_ identity: String) {
        activities.removeAll { $0.identity == identity }
        deleted.insert(identity)
        updateThreshold()
        refresh()
    }

    private func updateThreshold() {
        if !thresholdIsManual, let estimate = TrainingLoad.estimateThresholdHeartRate(activities, discipline: .run) {
            settings.thresholdHeartRate = estimate
        }
    }

    func removeAll() {
        activities = []
        settings = AthleteSettings()
        thresholdIsManual = false
        deleted = []
        refresh()
    }

    private func refresh() {
        series = TrainingLoad.series(activities, settings: settings, calendar: calendar)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        activities = stored.activities
        settings = stored.settings
        thresholdIsManual = stored.thresholdIsManual
        deleted = stored.deleted
        series = TrainingLoad.series(activities, settings: settings, calendar: calendar)
    }

    private func save() {
        let stored = Stored(activities: activities, settings: settings, thresholdIsManual: thresholdIsManual, deleted: deleted)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Saving the library failed: \(error)")
        }
    }
}
