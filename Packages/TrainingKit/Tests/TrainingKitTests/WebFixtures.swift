import Foundation
@testable import TrainingKit

struct WebFixtures {
    static let shared = try! WebFixtures()

    let activities: [Activity]
    let expected: Expected
    let calendar: Calendar
    let now: Date

    init() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
        }
        let web = try decoder.decode([WebActivity].self, from: Self.data("activities"))
        activities = web.map(\.activity)
        expected = try decoder.decode(Expected.self, from: Self.data("expected"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
        now = expected.now
    }

    func day(_ text: String) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private static func data(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }
}

struct WebActivity: Decodable {
    let start: Date
    let discipline: Discipline
    let garminType: String
    let title: String
    let durationMs: Double
    let distanceKm: Double?
    let avgHr: Double?
    let maxHr: Double?
    let calories: Double?

    var activity: Activity {
        Activity(
            start: start,
            discipline: discipline,
            sourceType: garminType,
            title: title,
            duration: durationMs / 1000,
            distance: distanceKm.map { $0 * 1000 },
            averageHeartRate: avgHr,
            maxHeartRate: maxHr,
            calories: calories
        )
    }
}

struct Expected: Decodable {
    struct Point: Decodable {
        let day: Date
        let tss: Double
        let ctl: Double
        let atl: Double
        let tsb: Double
    }

    struct DisciplineSeries: Decodable {
        let count: Int
        let last: Point?
    }

    struct Fitness: Decodable {
        let ctl: Double
        let tsb: Double
        let ctlTrend: Double

        var snapshot: FitnessSnapshot {
            FitnessSnapshot(fitness: ctl, form: tsb, fitnessTrend: ctlTrend)
        }
    }

    struct ReadinessCase: Decodable {
        struct Config: Decodable {
            let distance: RaceDistance
            let date: String?
            let targetSeconds: Double
            let weeklyHours: Double?
            let fromZero: Bool
        }

        struct Result: Decodable {
            struct Item: Decodable {
                let discipline: Discipline
                let percent: Int
                let weeklyKm: Double
                let targetWeeklyKm: Double
                let longestKm: Double
                let targetLongKm: Double
            }

            struct Step: Decodable {
                let discipline: Discipline
                let currentKm: Double
                let suggestedKm: Double
                let done: Bool
            }

            struct Pace: Decodable {
                let discipline: Discipline
                let currentSpeed: Double?
                let requiredSpeed: Double
                let ok: Bool
                let hasData: Bool
            }

            let overall: Int
            let volumeScore: Int
            let disciplines: [Item]
            let limiting: Discipline
            let monthsToReady: Int
            let weeksToRace: Int?
            let status: String?
            let hasVolume: Bool
            let ctl: Int?
            let tsb: Int?
            let ctlTrend: Double?
            let fitnessBonus: Int
            let nextWeek: [Step]
            let pace: [Pace]
        }

        let name: String
        let config: Config
        let fitness: Fitness?
        let result: Result
    }

    struct PlanFixture: Decodable {
        struct Workout: Decodable {
            let discipline: Discipline
            let title: String
            let distanceKm: Double?
        }

        struct Week: Decodable {
            let days: [[Workout]]
            let done: [Bool]

            var planWeek: PlanWeek {
                PlanWeek(
                    days: days.map { day in
                        day.map { PlannedWorkout(discipline: $0.discipline, title: $0.title, distance: $0.distanceKm.map { $0 * 1000 }) }
                    },
                    done: done
                )
            }
        }

        struct WeekResult: Decodable {
            struct Progress: Decodable {
                let done: Int
                let total: Int
                let complete: Bool
            }

            struct Volume: Decodable {
                let discipline: Discipline
                let km: Double
            }

            struct Compare: Decodable {
                let discipline: Discipline
                let planned: Double
                let actual: Double
            }

            let start: Date
            let end: Date
            let progress: Progress
            let volume: [Volume]
            let comparison: [Compare]
        }

        let startMonday: String
        let weeks: [Week]
        let results: [WeekResult]
    }

    struct Monday: Decodable {
        let input: Date
        let monday: Date
    }

    struct FormLabel: Decodable {
        let tsb: Double
        let label: String
    }

    let now: Date
    let lthr: Double
    let hrTss: [Double]
    let overall: [Point]
    let untilCount: Int
    let untilLast: Point
    let byDiscipline: [String: DisciplineSeries]
    let fitness: Fitness
    let readiness: [ReadinessCase]
    let volume: [String: [Double]]
    let plan: PlanFixture
    let mondays: [Monday]
    let tsb: [FormLabel]
}
