import Foundation
import Testing
@testable import TrainingKit

struct RaceDistanceTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func presetsBelongToTheirSport() {
        #expect(RacePreset.presets(for: .triathlon) == [.sprint, .olympic, .half, .full])
        #expect(RacePreset.presets(for: .run) == [.run5k, .run10k, .halfMarathon, .marathon])
        #expect(RacePreset.presets(for: .bike) == [.bike50, .bike100, .bike160])
        #expect(RacePreset.presets(for: .swim) == [.swim1500, .swim3k, .swim5k, .swim10k])
        #expect(RaceDistance(preset: .marathon).disciplines == [.run])
        #expect(RaceDistance.full.disciplines == [.swim, .bike, .run])
    }

    @Test func legacyDistancesKeepTheirValues() {
        #expect(RaceDistance.full.target(for: .bike) == (180_000, 120_000))
        #expect(RaceDistance.half.target(for: .swim) == (3_000, 1_900))
        #expect(RaceDistance.full.cutoff == 17 * 3600)
        #expect(RaceDistance.half.leg(for: .run) == 21_100)
        #expect(RaceDistance.full.longestCap(for: .run) == nil)
    }

    @Test func customDistanceMatchingAPresetUsesItsNorms() {
        let custom = RaceDistance(sport: .run, legs: [.run: 42_200])
        let marathon = RaceDistance(preset: .marathon)
        #expect(custom.isCustom)
        #expect(custom.target(for: .run) == marathon.target(for: .run))
        #expect(custom.longestCap(for: .run) == marathon.longestCap(for: .run))
        #expect(abs(custom.cutoff - marathon.cutoff) < 1)
    }

    @Test func ultraDistanceExtrapolatesBeyondTheMarathon() {
        let ultra = RaceDistance(sport: .run, legs: [.run: 100_000])
        let target = ultra.target(for: .run)
        let marathon = RaceDistance(preset: .marathon).target(for: .run)
        #expect(target.weekly > marathon.weekly)
        #expect(target.longest > marathon.longest)
        #expect(ultra.cutoff > RaceDistance(preset: .marathon).cutoff)
    }

    @Test func customTriathlonKeepsOnlyItsOwnLegs() {
        let custom = RaceDistance(sport: .triathlon, legs: [.swim: 2_000, .bike: 80_000, .run: 20_000])
        #expect(custom.isValid)
        #expect(custom.total == 102_000)
        #expect(custom.transitionTime == 8 * 60)
        #expect(!RaceDistance(sport: .run, legs: [:]).isValid)
        #expect(RaceDistance(sport: .bike, legs: [.bike: 70_000, .run: 5_000]).disciplines == [.bike])
    }

    @Test func distancesRoundTripThroughJSON() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let legacy = try decoder.decode(RaceDistance.self, from: Data("\"full\"".utf8))
        #expect(legacy == .full)
        let custom = RaceDistance(sport: .run, legs: [.run: 100_000])
        let decoded = try decoder.decode(RaceDistance.self, from: try encoder.encode(custom))
        #expect(decoded == custom)
        let config = RaceConfig(distance: RaceDistance(preset: .marathon), targetTime: 4 * 3600)
        #expect(try decoder.decode(RaceConfig.self, from: try encoder.encode(config)) == config)
    }

    @Test func singleSportReadinessHasOneDisciplineAndCappedLongest() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12))!
        let runs = (0..<8).map { week in
            Activity(
                start: calendar.date(byAdding: .day, value: -7 * week - 1, to: now)!,
                discipline: .run,
                sourceType: "running",
                title: "",
                duration: 3600,
                distance: 12_000
            )
        }
        let config = RaceConfig(distance: RaceDistance(preset: .marathon), targetTime: 3 * 3600)
        let readiness = ReadinessCalculator.compute(config: config, activities: runs, now: now, calendar: calendar)
        #expect(readiness.disciplines.map(\.discipline) == [.run])
        #expect(readiness.limiting == .run)
        #expect(readiness.disciplines[0].targetLongestDistance == 35_000)
        #expect(readiness.pace.count == 1)
        #expect(abs(readiness.pace[0].requiredSpeed - 42_200.0 / (3 * 3600)) < 0.0001)
    }

    @Test func backupKeepsGoalsTheWebVersionDoesNotKnow() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        let marathon = RaceConfig(distance: RaceDistance(preset: .marathon), targetTime: 4 * 3600)
        let data = try WebBackup.export(
            activities: [],
            deleted: [],
            settings: AthleteSettings(),
            thresholdIsManual: false,
            plans: [],
            raceConfig: marathon,
            calendar: calendar,
            now: now
        )
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["race_config_v1"] == nil)
        #expect(root["race_goal_v1"] != nil)
        #expect(try WebBackup(data: data, calendar: calendar).raceConfig == marathon)

        let full = RaceConfig(distance: .full, targetTime: 13 * 3600)
        let legacy = try WebBackup.export(
            activities: [],
            deleted: [],
            settings: AthleteSettings(),
            thresholdIsManual: false,
            plans: [],
            raceConfig: full,
            calendar: calendar,
            now: now
        )
        let legacyRoot = try #require(try JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        #expect(legacyRoot["race_config_v1"] != nil)
        #expect(legacyRoot["race_goal_v1"] != nil)
        #expect(try WebBackup(data: legacy, calendar: calendar).raceConfig == full)
    }

    @Test func manualNormsReplaceAutomaticOnes() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12))!
        let runs = (0..<4).map { week in
            Activity(
                start: calendar.date(byAdding: .day, value: -7 * week - 1, to: now)!,
                discipline: .run,
                sourceType: "running",
                title: "",
                duration: 3600,
                distance: 20_000
            )
        }
        var config = RaceConfig(distance: RaceDistance(preset: .halfMarathon), targetTime: 2 * 3600)
        #expect(ReadinessCalculator.norms(for: config) == ReadinessCalculator.automaticNorms(for: config))
        config.manualNorms = [RaceNorm(discipline: .run, weekly: 20_000, longest: 20_000)]
        #expect(config.hasManualNorms)
        let readiness = ReadinessCalculator.compute(config: config, activities: runs, model: .legacy, now: now, calendar: calendar)
        #expect(readiness.disciplines[0].targetWeeklyDistance == 20_000)
        #expect(readiness.disciplines[0].percent == 100)
        config.manualNorms = [RaceNorm(discipline: .run, weekly: 0, longest: 20_000)]
        #expect(ReadinessCalculator.norms(for: config) == ReadinessCalculator.automaticNorms(for: config))
    }
}
