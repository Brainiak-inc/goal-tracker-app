import Foundation
import Testing
@testable import TrainingKit

struct RacePredictorTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12))!
    }

    func run(daysAgo: Int, meters: Double, minutes: Double, discipline: Discipline = .run) -> Activity {
        Activity(
            start: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
            discipline: discipline,
            sourceType: discipline.rawValue,
            title: "",
            duration: minutes * 60,
            distance: meters
        )
    }

    @Test func halfMarathonFromATenKilometerEffort() throws {
        let config = RaceConfig(distance: RaceDistance(preset: .halfMarathon), targetTime: 2 * 3600)
        let prediction = try #require(RacePredictor.predict(config: config, activities: [run(daysAgo: 10, meters: 10_000, minutes: 50)], longest: 42_200, volumeRatio: 1, now: now))
        #expect(abs(prediction.time - 3000 * pow(2.11, 1.06)) < 0.5)
        #expect(prediction.distance == 21_100)
        #expect(prediction.exponent == 1.06)
    }

    @Test func missingLongRunsMakeTheMarathonSlower() throws {
        let config = RaceConfig(distance: RaceDistance(preset: .marathon), targetTime: 4 * 3600)
        let efforts = [run(daysAgo: 10, meters: 10_000, minutes: 50)]
        let ready = try #require(RacePredictor.predict(config: config, activities: efforts, longest: 42_200, volumeRatio: 1, now: now))
        let short = try #require(RacePredictor.predict(config: config, activities: efforts, longest: 21_100, volumeRatio: 1, now: now))
        #expect(short.time > ready.time)
        #expect(abs(short.exponent - 1.13) < 0.0001)
    }

    @Test func calibratedOnARealHalfMarathon() throws {
        let config = RaceConfig(distance: RaceDistance(preset: .halfMarathon), targetTime: 2.75 * 3600)
        let effort = Activity(
            start: calendar.date(byAdding: .day, value: -26, to: now)!,
            discipline: .run,
            sourceType: "running",
            title: "",
            duration: 34 * 60 + 21,
            distance: 5_010
        )
        let prediction = try #require(RacePredictor.predict(config: config, activities: [effort], longest: 12_120, volumeRatio: 0.35, now: now))
        let actual: TimeInterval = 3 * 3600 + 7 * 60 + 48
        #expect(abs(prediction.time - actual) / actual < 0.01)
        let afterTheRace = try #require(RacePredictor.predict(config: config, activities: [effort], longest: 21_100, volumeRatio: 0.35, now: now))
        #expect(afterTheRace.time > 2.75 * 3600)
    }

    @Test func lowWeeklyVolumeSlowsLongRaces() throws {
        let config = RaceConfig(distance: RaceDistance(preset: .marathon))
        let efforts = [run(daysAgo: 10, meters: 10_000, minutes: 50)]
        let trained = try #require(RacePredictor.predict(config: config, activities: efforts, longest: 42_200, volumeRatio: 1, now: now))
        let light = try #require(RacePredictor.predict(config: config, activities: efforts, longest: 42_200, volumeRatio: 0.3, now: now))
        #expect(light.time > trained.time)
    }

    @Test func ultraComparesLongRunsWithTheMarathon() throws {
        let config = RaceConfig(distance: RaceDistance(sport: .run, legs: [.run: 100_000]), targetTime: 12 * 3600)
        let prediction = try #require(RacePredictor.predict(config: config, activities: [run(daysAgo: 9, meters: 10_000, minutes: 50)], longest: 40_000, volumeRatio: 1, now: now))
        #expect(prediction.time > 10 * 3600 && prediction.time < 13 * 3600)
    }

    @Test func fastestRelativeEffortWins() throws {
        let config = RaceConfig(distance: RaceDistance(preset: .halfMarathon))
        let efforts = [
            run(daysAgo: 5, meters: 10_000, minutes: 60),
            run(daysAgo: 20, meters: 5_000, minutes: 22),
            run(daysAgo: 3, meters: 10_000, minutes: 20),
            run(daysAgo: 120, meters: 10_000, minutes: 40)
        ]
        let prediction = try #require(RacePredictor.predict(config: config, activities: efforts, longest: 42_200, volumeRatio: 1, now: now))
        #expect(prediction.effortDistance == 5_000)
        #expect(prediction.effortDuration == 22 * 60)
    }

    @Test func timedRacePredictsDistance() throws {
        let config = RaceConfig(distance: RaceDistance(sport: .run, legs: [.run: 60_000]), timeLimit: 6 * 3600)
        #expect(config.isTimed)
        #expect(config.targetTime == 6 * 3600)
        let prediction = try #require(RacePredictor.predict(config: config, activities: [run(daysAgo: 7, meters: 10_000, minutes: 50)], longest: 42_200, volumeRatio: 1, now: now))
        #expect(prediction.time == 6 * 3600)
        #expect(prediction.distance > 55_000 && prediction.distance < 68_000)
        #expect(prediction.exponent > 1.06)
    }

    @Test func timedRaceWithoutGoalDistanceStillHasNormsAndForecast() throws {
        let config = RaceConfig(distance: RaceDistance(sport: .run, legs: [:]), timeLimit: 24 * 3600)
        #expect(!config.hasGoalDistance)
        #expect(abs(config.planningDistance.leg(for: .run) - 168_000) < 1)
        let norms = ReadinessCalculator.norms(for: config)
        #expect(norms.count == 1 && norms[0].weekly > 0 && norms[0].longest > 0)
        let readiness = ReadinessCalculator.compute(config: config, activities: [run(daysAgo: 7, meters: 10_000, minutes: 50)], now: now, calendar: calendar)
        #expect(readiness.prediction?.time == TimeInterval(24 * 3600))
        #expect((readiness.prediction?.distance ?? 0) > 0)
        let decoded = try JSONDecoder().decode(RaceConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
        #expect(RaceConfig(distance: RaceDistance(sport: .run, legs: [.run: 150_000]), timeLimit: 24 * 3600).hasGoalDistance)
    }

    @Test func swimmingUsesItsOwnExponent() throws {
        let config = RaceConfig(distance: RaceDistance(preset: .swim3k))
        let prediction = try #require(RacePredictor.predict(config: config, activities: [run(daysAgo: 4, meters: 1_500, minutes: 30, discipline: .swim)], longest: 42_200, volumeRatio: 1, now: now))
        #expect(abs(prediction.time - 1800 * pow(2, 1.04)) < 0.5)
    }

    @Test func noPredictionWithoutSupportedData() {
        let efforts = [run(daysAgo: 10, meters: 10_000, minutes: 50)]
        #expect(RacePredictor.predict(config: RaceConfig(distance: .full), activities: efforts, longest: 42_200, volumeRatio: 1, now: now) == nil)
        #expect(RacePredictor.predict(config: RaceConfig(distance: RaceDistance(preset: .bike100)), activities: efforts, longest: 42_200, volumeRatio: 1, now: now) == nil)
        #expect(RacePredictor.predict(config: RaceConfig(distance: RaceDistance(preset: .marathon)), activities: [], longest: 42_200, volumeRatio: 1, now: now) == nil)
    }

    @Test func readinessCarriesThePrediction() {
        let config = RaceConfig(distance: RaceDistance(preset: .run10k), targetTime: 3600)
        let readiness = ReadinessCalculator.compute(config: config, activities: [run(daysAgo: 6, meters: 5_000, minutes: 25)], now: now, calendar: calendar)
        #expect(readiness.prediction?.discipline == .run)
        #expect(ReadinessCalculator.compute(config: RaceConfig(distance: .full), activities: [], now: now, calendar: calendar).prediction == nil)
    }
}
