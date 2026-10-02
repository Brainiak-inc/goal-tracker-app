import Foundation
import Testing
@testable import TrainingKit

struct DisciplineTests {
    @Test(arguments: [
        ("Running", Discipline.run),
        ("Trail Running", .run),
        ("Treadmill Running", .run),
        ("Cycling", .bike),
        ("Indoor Cycling", .bike),
        ("Mountain Biking", .bike),
        ("Pool Swim", .swim),
        ("Open Water Swimming", .swim),
        ("Strength Training", .strength),
        ("Walking", .other),
        ("Pilates", .other)
    ])
    func garminTypes(_ type: String, _ discipline: Discipline) {
        #expect(Discipline(garminType: type) == discipline)
    }
}

struct TrainingLoadTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func activity(hours: Double, heartRate: Double?, discipline: Discipline = .run, day: Int = 1) -> Activity {
        Activity(
            start: calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 7))!,
            discipline: discipline,
            sourceType: "Running",
            title: "Run",
            duration: hours * 3600,
            averageHeartRate: heartRate
        )
    }

    @Test func stressAtThresholdIsHundredPerHour() {
        let settings = AthleteSettings(thresholdHeartRate: 170)
        #expect(TrainingLoad.heartRateStress(activity(hours: 1, heartRate: 170), settings: settings) == 100)
        #expect(TrainingLoad.heartRateStress(activity(hours: 2, heartRate: 85), settings: settings) == 50)
    }

    @Test func stressWithoutHeartRateIsZero() {
        let settings = AthleteSettings()
        #expect(TrainingLoad.heartRateStress(activity(hours: 1, heartRate: nil), settings: settings) == 0)
        #expect(TrainingLoad.heartRateStress(activity(hours: 1, heartRate: 0), settings: settings) == 0)
    }

    @Test func disciplineThresholdOverridesDefault() {
        let settings = AthleteSettings(thresholdHeartRate: 170, thresholdHeartRateByDiscipline: [.bike: 160])
        let ride = activity(hours: 1, heartRate: 160, discipline: .bike)
        #expect(TrainingLoad.heartRateStress(ride, settings: settings) == 100)
    }

    @Test func emptySeries() {
        #expect(TrainingLoad.series([], settings: AthleteSettings(), calendar: calendar).isEmpty)
        #expect(FitnessSnapshot(series: []) == nil)
    }

    @Test func seriesCoversEveryDayIncludingRestDays() {
        let activities = [activity(hours: 1, heartRate: 170, day: 1), activity(hours: 1, heartRate: 170, day: 5)]
        let series = TrainingLoad.series(activities, settings: AthleteSettings(), calendar: calendar)
        #expect(series.count == 5)
        #expect(series.map(\.stress) == [100, 0, 0, 0, 100])
        #expect(series[0].form == 0)
    }

    @Test func thresholdEstimateIgnoresShortSessions() {
        let activities = [
            activity(hours: 0.25, heartRate: 190),
            activity(hours: 0.5, heartRate: 172),
            activity(hours: 1, heartRate: 165)
        ]
        #expect(TrainingLoad.estimateThresholdHeartRate(activities, discipline: .run) == 172)
        #expect(TrainingLoad.estimateThresholdHeartRate(activities, discipline: .bike) == nil)
    }
}

struct TrendTests {
    @Test func fitnessTrendNeedsEightDays() {
        let points = (0..<7).map { LoadPoint(day: Date(timeIntervalSince1970: Double($0) * 86_400), stress: 0, fitness: Double($0), fatigue: 0, form: 0) }
        #expect(Trend.fitness(points) == nil)
        let more = points + [LoadPoint(day: Date(timeIntervalSince1970: 7 * 86_400), stress: 0, fitness: 3, fatigue: 0, form: 0)]
        #expect(Trend.fitness(more)?.trend == .up)
        #expect(Trend(fitnessDelta: 0.5) == .flat)
        #expect(Trend(fitnessDelta: -0.6) == .down)
    }

    @Test func volumeTrendComparesWithPreviousThreeWeeks() {
        #expect(Trend.volume([10, 20, 30, 40, 40]) == .up)
        #expect(Trend.volume([10, 20, 30, 40, 31]) == .flat)
        #expect(Trend.volume([10, 30, 30, 30, 30]) == .flat)
        #expect(Trend.volume([30, 30, 30, 20]) == .down)
        #expect(Trend.volume([0, 0, 0, 5]) == .up)
        #expect(Trend.volume([0, 0, 0, 0]) == nil)
        #expect(Trend.volume([]) == nil)
    }

    @Test func displayRoundingMatchesWeb() {
        #expect((-6.5).displayRounded == -6)
        #expect(6.5.displayRounded == 7)
        #expect((-6.51).displayRounded == -7)
    }
}

struct PlanTests {
    @Test func restDaysDoNotCountTowardsProgress() {
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, distance: 8_000)]
        week.days[2] = [PlannedWorkout(discipline: .swim, distance: 1_500)]
        week.done[0] = true
        week.done[1] = true
        #expect(week.progress == WeekProgress(done: 1, total: 2))
        #expect(!week.progress.isComplete)

        week.done[2] = true
        #expect(week.progress.isComplete)
        #expect(!PlanWeek().progress.isComplete)
    }

    @Test func plannedVolumeSkipsNonTriathlonAndUndistanced() {
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, distance: 8_000), PlannedWorkout(discipline: .strength)]
        week.days[1] = [PlannedWorkout(discipline: .run, distance: 6_000), PlannedWorkout(discipline: .bike)]
        #expect(week.plannedVolume == [DisciplineVolume(discipline: .run, distance: 14_000)])
    }
}

struct ReadinessTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func noActivitiesMeansZeroAndSwimLimits() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let result = ReadinessCalculator.compute(config: RaceConfig(distance: .full), activities: [], now: now, calendar: calendar)
        #expect(result.overall == 0)
        #expect(!result.hasVolume)
        #expect(result.limiting == .swim)
        #expect(result.status == nil)
        #expect(result.pace.allSatisfy { !$0.hasData && !$0.isOnPace })
    }

    @Test func defaultTargetTimeIsCutoff() {
        #expect(RaceConfig(distance: .full).targetTime == 17 * 3600)
        #expect(RaceConfig(distance: .half).targetTime == 8.5 * 3600)
        #expect(ReadinessCalculator.paceFactor(RaceConfig(distance: .full)) == 1)
        #expect(ReadinessCalculator.paceFactor(RaceConfig(distance: .full, targetTime: 4 * 3600)) == 2)
    }
}
