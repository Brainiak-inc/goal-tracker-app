import Foundation
import Testing
@testable import TrainingKit

struct WebBackupTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func backup() throws -> WebBackup {
        let url = try #require(Bundle.module.url(forResource: "web-backup", withExtension: "json", subdirectory: "Fixtures"))
        return try WebBackup(data: Data(contentsOf: url), calendar: calendar)
    }

    @Test func activitiesKeepStoredDisciplineAndConvertUnits() throws {
        let activities = try backup().activities
        #expect(activities.count == 3)
        let run = try #require(activities.first { $0.sourceType == "Running" })
        #expect(run.start == Date(timeIntervalSince1970: 1_790_574_347))
        #expect(run.duration == 2057)
        #expect(close(run.distance, 4160))
        #expect(run.averageHeartRate == 158)
        let swim = try #require(activities.first { $0.discipline == .swim })
        #expect(close(swim.distance, 1500))
        let strength = try #require(activities.first { $0.sourceType == "Strength Training" })
        #expect(strength.discipline == .other)
        #expect(strength.distance == nil)
    }

    @Test func settingsAndDeletedKeys() throws {
        let backup = try backup()
        #expect(backup.settings?.thresholdHeartRate == 174)
        #expect(backup.settings?.thresholdHeartRate(for: .bike) == 160)
        #expect(backup.thresholdIsManual)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29))!
        #expect(backup.adherence.mark(.general, on: monday, calendar: calendar) == DayMark(status: .full))
        #expect(backup.adherence.mark(.general, on: tuesday, calendar: calendar) == DayMark(status: .missed, comment: "Болел"))
        #expect(backup.adherence.mark(.run, on: monday, calendar: calendar)?.status == .partial)
        let walking = Date(timeIntervalSince1970: 1_789_884_000)
        #expect(backup.deleted == ["\(walking.timeIntervalSince1970)|Walking"])
    }

    @Test func plansKeepIdsDatesAndDistances() throws {
        let plans = try backup().plans
        #expect(plans.map(\.name) == ["База · 2026", "Без дат"])
        let base = plans[0]
        #expect(base.startMonday == calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)))
        #expect(base.weeks.count == 2)
        #expect(base.weeks[0].days[0].first?.title == "Лёгкий")
        #expect(close(base.weeks[0].days[0].first?.distance, 8000))
        #expect(close(base.weeks[0].days[1].first?.distance, 1500))
        #expect(base.weeks[0].done[0])
        #expect(base.weeks[1].days[6].first?.distance == nil)

        let legacy = plans[1]
        #expect(legacy.startMonday == nil)
        #expect(legacy.weeks[0].done == Array(repeating: false, count: 7))
        #expect(legacy.weeks[0].days[0].first?.title == "Старый формат")
    }

    @Test func raceGoal() throws {
        let race = try #require(try backup().raceConfig)
        #expect(race.distance == .full)
        #expect(race.raceDay == calendar.date(from: DateComponents(year: 2027, month: 7, day: 12)))
        #expect(race.targetTime == 46800)
        #expect(race.fromZero)
    }

    @Test func rejectsOtherJson() {
        #expect(throws: WebBackup.ParseError.self) {
            try WebBackup(data: Data(#"{"hello":"world"}"#.utf8), calendar: calendar)
        }
        #expect(throws: (any Error).self) {
            try WebBackup(data: Data("not json".utf8), calendar: calendar)
        }
    }
}

struct SessionMatchingTests {
    func activity(_ offset: TimeInterval, duration: TimeInterval = 3600, discipline: Discipline = .run, source: String = "Running", heartRate: Double? = nil, externalID: String? = nil) -> Activity {
        Activity(
            start: Date(timeIntervalSince1970: 1_790_000_000 + offset),
            discipline: discipline,
            sourceType: source,
            title: externalID == nil ? "Morning run" : "",
            duration: duration,
            distance: externalID == nil ? nil : 10_000,
            averageHeartRate: heartRate,
            externalID: externalID
        )
    }

    @Test func healthCopyOfAnImportedWorkoutFillsGaps() {
        let imported = activity(0, heartRate: 150)
        let fromHealth = activity(40, duration: 3550, source: "running", heartRate: 149, externalID: "health:A")
        let result = ActivityMerge.merge([imported], with: [fromHealth])
        #expect(result.activities.count == 1)
        #expect(result.updated == 1)
        #expect(result.activities[0].title == "Morning run")
        #expect(result.activities[0].distance == 10_000)
        #expect(result.activities[0].averageHeartRate == 150)
    }

    @Test func differentSessionsStaySeparate() {
        let base = activity(0)
        #expect(!base.isSameSession(as: activity(300)))
        #expect(!base.isSameSession(as: activity(0, duration: 2000)))
        #expect(!base.isSameSession(as: activity(0, discipline: .bike)))
        #expect(base.isSameSession(as: activity(90, duration: 3300)))
    }

    @Test func healthUpdatesAndDeletionsUseExternalID() {
        let first = activity(0, externalID: "health:A")
        var changed = first
        changed.averageHeartRate = 155
        let merged = ActivityMerge.merge([first], with: [changed])
        #expect(merged.activities.count == 1)
        #expect(merged.activities[0].averageHeartRate == 155)

        let imported = activity(10_000)
        let remaining = ActivityMerge.removing(externalIDs: ["health:A"], from: merged.activities + [imported])
        #expect(remaining == [imported])
    }
}
