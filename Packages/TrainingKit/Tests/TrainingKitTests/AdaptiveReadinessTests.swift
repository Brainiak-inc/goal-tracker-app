import Foundation
import Testing
@testable import TrainingKit

struct AdaptiveReadinessTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12))!
    }

    let norm = RaceNorm(discipline: .run, weekly: 30_000, longest: 15_000)

    func run(daysAgo: Double, meters: Double, minutes: Double = 60, heartRate: Double? = nil, climb: Double? = nil) -> Activity {
        Activity(
            start: now.addingTimeInterval(-daysAgo * 86_400),
            discipline: .run,
            sourceType: "running",
            title: "",
            duration: minutes * 60,
            distance: meters,
            averageHeartRate: heartRate,
            elevationGain: climb
        )
    }

    func evaluate(_ activities: [Activity], daysToRace: Double? = nil, settings: AthleteSettings? = nil) -> DisciplineReadiness {
        AdaptiveReadiness.evaluate(norm, activities: activities, settings: settings, daysToRace: daysToRace, now: now, calendar: calendar)
    }

    @Test func recentWeeksCountMore() {
        let recent = evaluate([run(daysAgo: 1, meters: 20_000), run(daysAgo: 8, meters: 20_000)])
        let old = evaluate([run(daysAgo: 29, meters: 20_000), run(daysAgo: 36, meters: 20_000)])
        #expect(recent.weeklyDistance > old.weeklyDistance)
        #expect(recent.percent > old.percent)
    }

    @Test func taperDoesNotLowerReadiness() {
        let build = (2..<8).map { run(daysAgo: Double($0 * 7 + 1), meters: 30_000) }
        let taper = [run(daysAgo: 1, meters: 10_000), run(daysAgo: 8, meters: 15_000)]
        let racing = evaluate(build + taper, daysToRace: 10)
        let training = evaluate(build + taper)
        #expect(racing.weeklyDistance > training.weeklyDistance)
        #expect(racing.percent > training.percent)
    }

    @Test func gapsLowerConsistency() {
        let steady = evaluate((0..<6).map { run(daysAgo: Double($0 * 7 + 1), meters: 10_000) })
        let patchy = evaluate([run(daysAgo: 1, meters: 30_000), run(daysAgo: 22, meters: 30_000)])
        #expect(steady.activeWeeks == 6)
        #expect(patchy.activeWeeks == 2)
    }

    @Test func climbingCountsAsExtraDistance() {
        let flat = evaluate([run(daysAgo: 2, meters: 10_000)])
        let hilly = evaluate([run(daysAgo: 2, meters: 10_000, climb: 500)])
        #expect(hilly.longestDistance == 15_000)
        #expect(flat.longestDistance == 10_000)
    }

    @Test func oldLongRunsFade() {
        let fresh = evaluate([run(daysAgo: 20, meters: 20_000)])
        let stale = evaluate([run(daysAgo: 80, meters: 20_000)])
        #expect(fresh.longestDistance == 20_000)
        #expect(stale.longestDistance < 20_000 && stale.longestDistance >= 15_000)
    }

    @Test func fitnessJoinsWhenHeartRateExists() {
        let settings = AthleteSettings(thresholdHeartRate: 170)
        let runs = (0..<42).map { run(daysAgo: Double($0) + 0.5, meters: 5_000, minutes: 30, heartRate: 150) }
        let withLoad = evaluate(runs, settings: settings)
        #expect(withLoad.fitness != nil)
        #expect((withLoad.targetFitness ?? 0) > 0)
        let withoutHeartRate = evaluate(runs.map { var activity = $0; activity.averageHeartRate = nil; return activity }, settings: settings)
        #expect(withoutHeartRate.fitness == nil)
    }

    @Test func legacyModelStaysAvailable() {
        let config = RaceConfig(distance: RaceDistance(preset: .run10k), targetTime: 3600)
        let runs = (0..<6).map { run(daysAgo: Double($0 * 7 + 1), meters: 20_000) }
        let legacy = ReadinessCalculator.compute(config: config, activities: runs, model: .legacy, now: now, calendar: calendar)
        let adaptive = ReadinessCalculator.compute(config: config, activities: runs, now: now, calendar: calendar)
        #expect(legacy.disciplines[0].activeWeeks == nil)
        #expect(adaptive.disciplines[0].activeWeeks == 6)
    }
}
