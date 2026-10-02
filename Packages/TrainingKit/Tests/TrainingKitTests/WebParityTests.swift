import Foundation
import Testing
@testable import TrainingKit

@Suite("Parity with the web version")
struct WebParityTests {
    let fixtures = WebFixtures.shared

    var settings: AthleteSettings {
        AthleteSettings(thresholdHeartRate: fixtures.expected.lthr)
    }

    @Test func thresholdHeartRateEstimate() {
        let estimate = TrainingLoad.estimateThresholdHeartRate(fixtures.activities, discipline: .run)
        #expect(estimate == fixtures.expected.lthr)
    }

    @Test func heartRateStressPerActivity() {
        let stress = fixtures.activities.map { TrainingLoad.heartRateStress($0, settings: settings) }
        #expect(stress.count == fixtures.expected.hrTss.count)
        for (actual, expected) in zip(stress, fixtures.expected.hrTss) {
            #expect(close(actual, expected))
        }
    }

    @Test func overallSeries() {
        let series = TrainingLoad.series(fixtures.activities, settings: settings, calendar: fixtures.calendar)
        #expect(series.count == fixtures.expected.overall.count)
        for (point, expected) in zip(series, fixtures.expected.overall) {
            expectPoint(point, expected)
        }
    }

    @Test func seriesExtendsUntilDate() {
        let until = fixtures.now.addingTimeInterval(5 * 86_400)
        let series = TrainingLoad.series(fixtures.activities, settings: settings, calendar: fixtures.calendar, until: until)
        #expect(series.count == fixtures.expected.untilCount)
        if let last = series.last {
            expectPoint(last, fixtures.expected.untilLast)
        }
    }

    @Test(arguments: Discipline.allCases)
    func disciplineSeries(_ discipline: Discipline) throws {
        let expected = try #require(fixtures.expected.byDiscipline[discipline.rawValue])
        let series = TrainingLoad.series(fixtures.activities, settings: settings, calendar: fixtures.calendar) {
            $0.discipline == discipline
        }
        #expect(series.count == expected.count)
        if let last = series.last, let expectedLast = expected.last {
            expectPoint(last, expectedLast)
        }
    }

    @Test func fitnessSnapshot() throws {
        let series = TrainingLoad.series(fixtures.activities, settings: settings, calendar: fixtures.calendar)
        let snapshot = try #require(FitnessSnapshot(series: series))
        #expect(close(snapshot.fitness, fixtures.expected.fitness.ctl))
        #expect(close(snapshot.form, fixtures.expected.fitness.tsb))
        #expect(close(snapshot.fitnessTrend, fixtures.expected.fitness.ctlTrend))
    }

    @Test(arguments: WebFixtures.shared.expected.readiness.map(\.name))
    func readiness(_ name: String) throws {
        let item = try #require(fixtures.expected.readiness.first { $0.name == name })
        let config = RaceConfig(
            distance: item.config.distance,
            raceDay: item.config.date.map(fixtures.day),
            targetTime: item.config.targetSeconds,
            weeklyHours: item.config.weeklyHours,
            fromZero: item.config.fromZero
        )
        let result = ReadinessCalculator.compute(
            config: config,
            activities: fixtures.activities,
            fitness: item.fitness?.snapshot,
            now: fixtures.now,
            calendar: fixtures.calendar
        )
        let expected = item.result

        #expect(result.overall == expected.overall)
        #expect(result.volumeScore == expected.volumeScore)
        #expect(result.limiting == expected.limiting)
        #expect(result.monthsToReady == expected.monthsToReady)
        #expect(result.weeksToRace == expected.weeksToRace)
        #expect(result.status?.webValue == expected.status)
        #expect(result.hasVolume == expected.hasVolume)
        #expect(result.fitness == expected.ctl)
        #expect(result.form == expected.tsb)
        #expect(result.fitnessBonus == expected.fitnessBonus)

        for (actual, web) in zip(result.disciplines, expected.disciplines) {
            #expect(actual.discipline == web.discipline)
            #expect(actual.percent == web.percent)
            #expect(close(actual.weeklyDistance, web.weeklyKm * 1000))
            #expect(close(actual.targetWeeklyDistance, web.targetWeeklyKm * 1000))
            #expect(close(actual.longestDistance, web.longestKm * 1000))
            #expect(close(actual.targetLongestDistance, web.targetLongKm * 1000))
        }
        for (actual, web) in zip(result.nextWeek, expected.nextWeek) {
            #expect(actual.discipline == web.discipline)
            #expect(actual.isDone == web.done)
            #expect(close(actual.currentDistance, web.currentKm * 1000))
            #expect(close(actual.suggestedDistance, web.suggestedKm * 1000))
        }
        for (actual, web) in zip(result.pace, expected.pace) {
            #expect(actual.discipline == web.discipline)
            #expect(actual.hasData == web.hasData)
            #expect(actual.isOnPace == web.ok)
            #expect(close(actual.requiredSpeed * 3.6, web.requiredSpeed))
            #expect(close(actual.currentSpeed.map { $0 * 3.6 }, web.currentSpeed))
        }
    }

    @Test(arguments: Discipline.triathlon)
    func weeklyVolume(_ discipline: Discipline) throws {
        let expected = try #require(fixtures.expected.volume[discipline.rawValue])
        let series = WeeklyVolume.series(
            fixtures.activities,
            discipline: discipline,
            weeks: 10,
            now: fixtures.now,
            calendar: fixtures.calendar
        )
        #expect(series.count == expected.count)
        for (actual, web) in zip(series, expected) {
            #expect(close(actual, web * 1000))
        }
    }

    @Test func planWeeks() {
        let plan = TrainingPlan(
            name: "Base",
            startMonday: fixtures.day(fixtures.expected.plan.startMonday),
            weeks: fixtures.expected.plan.weeks.map(\.planWeek)
        )
        for (index, web) in fixtures.expected.plan.results.enumerated() {
            let week = plan.weeks[index]
            let start = plan.weekStart(index, calendar: fixtures.calendar)
            #expect(start == web.start)

            #expect(week.progress.done == web.progress.done)
            #expect(week.progress.total == web.progress.total)
            #expect(week.progress.isComplete == web.progress.complete)

            #expect(week.plannedVolume.map(\.discipline) == web.volume.map(\.discipline))
            for (actual, expected) in zip(week.plannedVolume, web.volume) {
                #expect(close(actual.distance, expected.km * 1000))
            }

            let comparison = week.comparison(with: fixtures.activities, from: web.start, to: web.end)
            #expect(comparison.map(\.discipline) == web.comparison.map(\.discipline))
            for (actual, expected) in zip(comparison, web.comparison) {
                #expect(close(actual.planned, expected.planned * 1000))
                #expect(close(actual.actual, expected.actual * 1000))
            }
        }
    }

    @Test func mondays() {
        for item in fixtures.expected.mondays {
            #expect(fixtures.calendar.monday(of: item.input) == item.monday)
        }
    }

    @Test func formZones() {
        let labels: [String: FormZone] = [
            "свежесть": .fresh,
            "норма": .neutral,
            "рост формы": .building,
            "перегрузка": .overreaching
        ]
        for item in fixtures.expected.tsb {
            #expect(FormZone(form: item.tsb) == labels[item.label])
        }
    }

    private func expectPoint(_ point: LoadPoint, _ expected: Expected.Point) {
        #expect(point.day == expected.day)
        #expect(close(point.stress, expected.tss))
        #expect(close(point.fitness, expected.ctl))
        #expect(close(point.fatigue, expected.atl))
        #expect(close(point.form, expected.tsb))
    }
}

private extension RaceStatus {
    var webValue: String {
        switch self {
        case .ahead: "ahead"
        case .onTrack: "ontrack"
        case .behind: "behind"
        }
    }
}

func close(_ a: Double?, _ b: Double?) -> Bool {
    switch (a, b) {
    case (nil, nil):
        return true
    case let (a?, b?):
        return abs(a - b) <= 1e-6 * max(1, abs(a), abs(b))
    default:
        return false
    }
}
