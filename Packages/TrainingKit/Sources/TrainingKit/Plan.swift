import Foundation

public struct PlannedWorkout: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var discipline: Discipline
    public var title: String
    public var note: String
    public var distance: Double?

    public init(id: UUID = UUID(), discipline: Discipline, title: String = "", note: String = "", distance: Double? = nil) {
        self.id = id
        self.discipline = discipline
        self.title = title
        self.note = note
        self.distance = distance
    }
}

public struct PlanWeek: Codable, Hashable, Identifiable, Sendable {
    public static let dayCount = 7

    public var id: UUID
    public var days: [[PlannedWorkout]]
    public var done: [Bool]

    public init(id: UUID = UUID(), days: [[PlannedWorkout]]? = nil, done: [Bool]? = nil) {
        self.id = id
        self.days = days ?? Array(repeating: [], count: Self.dayCount)
        self.done = done ?? Array(repeating: false, count: Self.dayCount)
    }

    public var progress: WeekProgress {
        var total = 0
        var completed = 0
        for (index, day) in days.enumerated() where !day.isEmpty {
            total += 1
            if done.indices.contains(index), done[index] {
                completed += 1
            }
        }
        return WeekProgress(done: completed, total: total)
    }

    public var plannedVolume: [DisciplineVolume] {
        var totals: [Discipline: Double] = [:]
        for workout in days.joined() where workout.discipline.isTriathlon {
            guard let distance = workout.distance else { continue }
            totals[workout.discipline, default: 0] += distance
        }
        return Discipline.triathlon.compactMap { discipline in
            totals[discipline].map { DisciplineVolume(discipline: discipline, distance: $0) }
        }
    }

    public func comparison(with activities: [Activity], from start: Date, to end: Date) -> [VolumeComparison] {
        var planned: [Discipline: Double] = [:]
        for item in plannedVolume {
            planned[item.discipline] = item.distance
        }
        var actual: [Discipline: Double] = [:]
        for activity in activities where activity.discipline.isTriathlon {
            guard let distance = activity.distance, activity.start >= start, activity.start < end else { continue }
            actual[activity.discipline, default: 0] += distance
        }
        return Discipline.triathlon
            .filter { planned[$0] != nil || actual[$0] != nil }
            .map { VolumeComparison(discipline: $0, planned: planned[$0] ?? 0, actual: actual[$0] ?? 0) }
    }
}

public struct WeekProgress: Hashable, Sendable {
    public let done: Int
    public let total: Int

    public var isComplete: Bool { total > 0 && done == total }
}

public struct DisciplineVolume: Hashable, Sendable {
    public let discipline: Discipline
    public let distance: Double
}

public struct VolumeComparison: Hashable, Sendable {
    public let discipline: Discipline
    public let planned: Double
    public let actual: Double
}

public struct TrainingPlan: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var startMonday: Date?
    public var weeks: [PlanWeek]

    public init(id: UUID = UUID(), name: String, startMonday: Date? = nil, weeks: [PlanWeek] = []) {
        self.id = id
        self.name = name
        self.startMonday = startMonday
        self.weeks = weeks
    }

    public func weekStart(_ weekIndex: Int, calendar: Calendar) -> Date? {
        startMonday.map { calendar.adding(days: weekIndex * 7, to: calendar.startOfDay(for: $0)) }
    }

    public func day(_ dayIndex: Int, ofWeek weekIndex: Int, calendar: Calendar) -> Date? {
        weekStart(weekIndex, calendar: calendar).map { calendar.adding(days: dayIndex, to: $0) }
    }
}
