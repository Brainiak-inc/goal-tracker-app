import Foundation
import Testing
@testable import TrainingKit

struct WorkoutMatchingTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func at(_ day: Int, _ hour: Int, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func activity(_ date: Date, _ discipline: Discipline, _ distance: Double?) -> Activity {
        Activity(start: date, discipline: discipline, sourceType: discipline.rawValue, title: "", duration: 1800, distance: distance)
    }

    @Test func workoutsMatchSameDayAndDiscipline() {
        let run = PlannedWorkout(discipline: .run, distance: 8_000)
        let swim = PlannedWorkout(discipline: .swim, distance: 1_500)
        let morningRun = PlannedWorkout(discipline: .run, distance: 6_000)
        let eveningRun = PlannedWorkout(discipline: .run, distance: 4_000)
        var week = PlanWeek()
        week.days[0] = [run]
        week.days[1] = [swim]
        week.days[6] = [morningRun, eveningRun]
        let plan = TrainingPlan(name: "Base", startMonday: at(28, 0), weeks: [week])
        let activities = [
            activity(at(28, 7), .run, 7_800),
            activity(at(28, 18), .bike, 20_000),
            activity(at(29, 7), .run, 3_000),
            activity(at(4, 7, month: 10), .run, 6_100),
            activity(at(4, 19, month: 10), .run, 3_900),
            activity(at(4, 20, month: 10), .run, 1_000)
        ]
        let actuals = plan.actuals(forWeek: 0, activities: activities, calendar: calendar)
        #expect(actuals[run.id]?.distance == 7_800)
        #expect(abs((actuals[run.id]?.completion(of: run.distance) ?? 0) - 0.975) < 1e-9)
        #expect(actuals[swim.id] == nil)
        #expect(actuals[morningRun.id]?.distance == 6_100)
        #expect(actuals[eveningRun.id]?.distance == 4_900)
    }

    @Test func undatedPlansHaveNoActuals() {
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, distance: 8_000)]
        let plan = TrainingPlan(name: "Free", weeks: [week])
        #expect(plan.actuals(forWeek: 0, activities: [activity(at(28, 7), .run, 8_000)], calendar: calendar).isEmpty)
        #expect(WorkoutActual(activities: []).completion(of: nil) == nil)
    }
}

struct WeekStartsTests {
    @Test func weekStartsEndWithLastCompleteWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
        let starts = WeeklyVolume.weekStarts(weeks: 3, now: now, calendar: calendar)
        let expected = [7, 14, 21].map { calendar.date(from: DateComponents(year: 2026, month: 9, day: $0))! }
        #expect(starts == expected)
    }
}

struct WebBackupExportTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func exportRoundTrips() throws {
        let start = Date(timeIntervalSince1970: 1_790_574_347.5)
        let activities = [
            Activity(start: start, discipline: .run, sourceType: "Running", title: "Easy", duration: 2057, distance: 4160, averageHeartRate: 158, maxHeartRate: 190, calories: 360),
            Activity(start: start.addingTimeInterval(86_400), discipline: .swim, sourceType: "swimming", title: "", duration: 2400, distance: 1500, externalID: "health:X")
        ]
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, title: "Easy", note: "Zone 2", distance: 8_000)]
        week.days[3] = [PlannedWorkout(discipline: .strength)]
        week.done[0] = true
        let plans = [
            TrainingPlan(name: "Base", startMonday: calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)), weeks: [week]),
            TrainingPlan(name: "Free", weeks: [PlanWeek()])
        ]
        let race = RaceConfig(distance: .half, raceDay: calendar.date(from: DateComponents(year: 2027, month: 6, day: 6)), targetTime: 6 * 3600, fromZero: true)
        let deleted: Set<String> = ["\(start.timeIntervalSince1970)|Walking"]
        let settings = AthleteSettings(thresholdHeartRate: 174, thresholdHeartRateByDiscipline: [.bike: 160])

        let data = try WebBackup.export(
            activities: activities,
            deleted: deleted,
            settings: settings,
            thresholdIsManual: true,
            plans: plans,
            raceConfig: race,
            calendar: calendar,
            now: start
        )
        let backup = try WebBackup(data: data, calendar: calendar)

        #expect(backup.activities.count == 2)
        #expect(backup.activities[0].start == activities[0].start)
        #expect(backup.activities[0].title == "Easy")
        #expect(close(backup.activities[0].distance, 4160))
        #expect(backup.activities[1].discipline == .swim)
        #expect(backup.deleted == deleted)
        #expect(backup.settings == settings)
        #expect(backup.thresholdIsManual)
        #expect(backup.plans == plans)
        #expect(backup.raceConfig == race)
        #expect(backup.adherence.isEmpty)

        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["adherence_v1"] == nil)
        #expect(root["app"] as? String == "ironman-tracker")
    }

    @Test func adherenceRoundTrips() throws {
        var adherence = AdherenceBook()
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!
        adherence.setMark(DayMark(status: .partial, comment: "  Short run "), .run, on: day, calendar: calendar)
        let data = try WebBackup.export(
            activities: [],
            deleted: [],
            settings: AthleteSettings(),
            thresholdIsManual: false,
            plans: [],
            raceConfig: nil,
            adherence: adherence,
            preferences: ["unitSystem": "imperial"],
            calendar: calendar,
            now: day
        )
        let backup = try WebBackup(data: data, calendar: calendar)
        #expect(backup.adherence == adherence)
        #expect(backup.preferences == ["unitSystem": "imperial"])
        #expect(backup.adherence.mark(.run, on: day, calendar: calendar)?.comment == "Short run")
    }
}

struct AdherenceTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func yearGridCoversFullWeeks() {
        let weeks = YearGrid.weeks(year: 2026, calendar: calendar)
        #expect(weeks.count == 53)
        #expect(weeks.first?.cells.first?.date == day(2025, 12, 29))
        #expect(weeks.first?.cells.first?.isInYear == false)
        #expect(weeks.last?.cells.last?.date == day(2027, 1, 3))
        #expect(weeks.allSatisfy { $0.cells.count == 7 })
        let monthStarts = weeks.compactMap(\.startsMonth)
        #expect(monthStarts == (1...12).map { day(2026, $0, 1) })
    }

    @Test func marksSetClearAndCount() {
        var book = AdherenceBook()
        book.setMark(DayMark(status: .full), .general, on: day(2026, 9, 28), calendar: calendar)
        book.setMark(DayMark(status: .missed), .general, on: day(2026, 9, 29), calendar: calendar)
        book.setMark(DayMark(status: .full), .general, on: day(2025, 9, 29), calendar: calendar)
        #expect(book.counts(.general, year: 2026) == [.full: 1, .missed: 1])
        book.setMark(nil, .general, on: day(2026, 9, 29), calendar: calendar)
        #expect(book.mark(.general, on: day(2026, 9, 29), calendar: calendar) == nil)
        #expect(!book.isEmpty)

        var other = AdherenceBook()
        other.setMark(DayMark(status: .partial), .general, on: day(2026, 9, 28), calendar: calendar)
        book.merge(other)
        #expect(book.mark(.general, on: day(2026, 9, 28), calendar: calendar)?.status == .partial)
    }
}
