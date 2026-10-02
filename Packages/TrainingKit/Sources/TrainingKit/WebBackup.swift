import Foundation

public struct WebBackup: Sendable {
    public enum ParseError: Error {
        case notABackup
    }

    public var activities: [Activity] = []
    public var deleted: Set<String> = []
    public var settings: AthleteSettings?
    public var thresholdIsManual = false
    public var plans: [TrainingPlan] = []
    public var raceConfig: RaceConfig?
    public var adherence = AdherenceBook()
    public var preferences: [String: String] = [:]

    public init(data: Data, calendar: Calendar) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.notABackup
        }
        let knownKeys = ["activities_v1", "settings_v1", "plan_v1", "race_config_v1", "race_goal_v1"]
        guard knownKeys.contains(where: { root[$0] != nil }) else {
            throw ParseError.notABackup
        }

        func stored<T: Decodable>(_ key: String, as type: T.Type) -> T? {
            guard let text = root[key] as? String, let data = text.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }

        activities = (stored("activities_v1", as: [StoredActivity].self) ?? []).compactMap(\.activity)
        deleted = Set((stored("deleted_v1", as: [String].self) ?? []).compactMap(Self.identity(fromWebKey:)))
        if let stored = stored("settings_v1", as: StoredSettings.self) {
            var byDiscipline: [Discipline: Double] = [:]
            for (key, value) in stored.lthrByDiscipline ?? [:] {
                if let discipline = Discipline(rawValue: key) {
                    byDiscipline[discipline] = value
                }
            }
            settings = AthleteSettings(
                thresholdHeartRate: stored.defaultLthr ?? AthleteSettings.fallbackThresholdHeartRate,
                thresholdHeartRateByDiscipline: byDiscipline
            )
        }
        thresholdIsManual = (root["lthr_manual_v1"] as? String) == "true"
        plans = (stored("plan_v1", as: [StoredPlan].self) ?? []).map { $0.plan(calendar: calendar) }
        raceConfig = stored("race_goal_v1", as: RaceConfig.self)
            ?? stored("race_config_v1", as: StoredRace.self).map { $0.config(calendar: calendar) }
        adherence = stored("adherence_v1", as: AdherenceBook.self) ?? AdherenceBook()
        preferences = stored("app_preferences_v1", as: [String: String].self) ?? [:]
    }

    public static func export(
        activities: [Activity],
        deleted: Set<String>,
        settings: AthleteSettings,
        thresholdIsManual: Bool,
        plans: [TrainingPlan],
        raceConfig: RaceConfig?,
        adherence: AdherenceBook = AdherenceBook(),
        preferences: [String: String] = [:],
        calendar: Calendar,
        now: Date
    ) throws -> Data {
        func text<T: Encodable>(_ value: T) throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        func day(_ date: Date?) -> String? {
            date.map { date in
                let parts = calendar.dateComponents([.year, .month, .day], from: date)
                return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            }
        }
        let isoFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

        let storedActivities = activities.map { activity in
            ExportedActivity(
                start: activity.start.formatted(isoFormat),
                discipline: activity.discipline.rawValue,
                garminType: activity.sourceType,
                title: activity.title,
                durationMs: (activity.duration * 1000).rounded(),
                distanceKm: activity.distance.map { $0 / 1000 },
                avgHr: activity.averageHeartRate,
                maxHr: activity.maxHeartRate,
                calories: activity.calories
            )
        }
        let storedPlans = plans.map { plan in
            ExportedPlan(
                id: plan.id.uuidString.lowercased(),
                name: plan.name,
                startMonday: day(plan.startMonday),
                weeks: plan.weeks.map { week in
                    ExportedPlan.Week(
                        id: week.id.uuidString.lowercased(),
                        days: week.days.map { day in
                            day.map { workout in
                                ExportedPlan.Workout(
                                    id: workout.id.uuidString.lowercased(),
                                    discipline: workout.discipline.rawValue,
                                    title: workout.title,
                                    note: workout.note,
                                    distanceKm: workout.distance.map { $0 / 1000 }
                                )
                            }
                        },
                        done: week.done
                    )
                }
            )
        }
        let deletedKeys = deleted.compactMap { identity -> String? in
            guard let separator = identity.firstIndex(of: "|"),
                  let seconds = Double(identity[..<separator]) else { return nil }
            return "\(Date(timeIntervalSince1970: seconds).formatted(isoFormat))|\(identity[identity.index(after: separator)...])"
        }.sorted()

        var root: [String: Any] = [
            "app": "ironman-tracker",
            "version": 1,
            "exportedAt": now.formatted(isoFormat),
            "activities_v1": try text(storedActivities),
            "settings_v1": try text(ExportedSettings(
                defaultLthr: settings.thresholdHeartRate,
                lthrByDiscipline: Dictionary(uniqueKeysWithValues: settings.thresholdHeartRateByDiscipline.map { ($0.key.rawValue, $0.value) })
            )),
            "lthr_manual_v1": thresholdIsManual ? "true" : "false",
            "plan_v1": try text(storedPlans),
            "deleted_v1": try text(deletedKeys)
        ]
        if !adherence.isEmpty {
            root["adherence_v1"] = try text(adherence)
        }
        if !preferences.isEmpty {
            root["app_preferences_v1"] = try text(preferences)
        }
        if let raceConfig {
            root["race_goal_v1"] = try text(raceConfig)
            if let preset = raceConfig.distance.preset, raceConfig.distance.isWebCompatible {
                root["race_config_v1"] = try text(ExportedRace(
                    distance: preset.rawValue,
                    date: day(raceConfig.raceDay),
                    targetSeconds: raceConfig.targetTime,
                    weeklyHours: raceConfig.weeklyHours,
                    fromZero: raceConfig.fromZero
                ))
            }
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    static func identity(fromWebKey key: String) -> String? {
        guard let separator = key.firstIndex(of: "|"),
              let date = webDate(String(key[..<separator])) else { return nil }
        return "\(date.timeIntervalSince1970)|\(key[key.index(after: separator)...])"
    }

    static func webDate(_ text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    static func day(_ text: String?, calendar: Calendar) -> Date? {
        guard let parts = text?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

private struct StoredActivity: Decodable {
    let start: String
    let discipline: String?
    let garminType: String
    let title: String?
    let durationMs: Double
    let distanceKm: Double?
    let avgHr: Double?
    let maxHr: Double?
    let calories: Double?

    var activity: Activity? {
        guard let date = WebBackup.webDate(start) else { return nil }
        return Activity(
            start: date,
            discipline: discipline.flatMap(Discipline.init(rawValue:)) ?? Discipline(garminType: garminType),
            sourceType: garminType,
            title: title ?? garminType,
            duration: durationMs / 1000,
            distance: distanceKm.map { $0 * 1000 },
            averageHeartRate: avgHr,
            maxHeartRate: maxHr,
            calories: calories
        )
    }
}

private struct StoredSettings: Decodable {
    let defaultLthr: Double?
    let lthrByDiscipline: [String: Double]?
}

private struct StoredPlan: Decodable {
    struct Week: Decodable {
        let id: String?
        let days: [[Workout]]
        let done: [Bool]?
    }

    struct Workout: Decodable {
        let id: String?
        let discipline: String
        let title: String?
        let note: String?
        let distanceKm: Double?
    }

    let id: String?
    let name: String
    let startMonday: String?
    let weeks: [Week]

    func plan(calendar: Calendar) -> TrainingPlan {
        TrainingPlan(
            id: id.flatMap(UUID.init(uuidString:)) ?? UUID(),
            name: name,
            startMonday: WebBackup.day(startMonday, calendar: calendar),
            weeks: weeks.map { week in
                var days = week.days.map { day in
                    day.map { workout in
                        PlannedWorkout(
                            id: workout.id.flatMap(UUID.init(uuidString:)) ?? UUID(),
                            discipline: Discipline(rawValue: workout.discipline) ?? .other,
                            title: workout.title ?? "",
                            note: workout.note ?? "",
                            distance: workout.distanceKm.map { $0 * 1000 }
                        )
                    }
                }
                days += Array(repeating: [], count: max(0, PlanWeek.dayCount - days.count))
                var done = week.done ?? []
                done += Array(repeating: false, count: max(0, PlanWeek.dayCount - done.count))
                return PlanWeek(
                    id: week.id.flatMap(UUID.init(uuidString:)) ?? UUID(),
                    days: Array(days.prefix(PlanWeek.dayCount)),
                    done: Array(done.prefix(PlanWeek.dayCount))
                )
            }
        )
    }
}

private struct StoredRace: Decodable {
    let distance: RaceDistance
    let date: String?
    let targetSeconds: Double?
    let weeklyHours: Double?
    let fromZero: Bool?

    func config(calendar: Calendar) -> RaceConfig {
        RaceConfig(
            distance: distance,
            raceDay: WebBackup.day(date, calendar: calendar),
            targetTime: targetSeconds.flatMap { $0 > 0 ? $0 : nil },
            weeklyHours: weeklyHours,
            fromZero: fromZero ?? false
        )
    }
}

private struct ExportedActivity: Encodable {
    let start: String
    let discipline: String
    let garminType: String
    let title: String
    let durationMs: Double
    let distanceKm: Double?
    let avgHr: Double?
    let maxHr: Double?
    let calories: Double?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(discipline, forKey: .discipline)
        try container.encode(garminType, forKey: .garminType)
        try container.encode(title, forKey: .title)
        try container.encode(durationMs, forKey: .durationMs)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encode(avgHr, forKey: .avgHr)
        try container.encode(maxHr, forKey: .maxHr)
        try container.encode(calories, forKey: .calories)
    }

    enum CodingKeys: String, CodingKey {
        case start, discipline, garminType, title, durationMs, distanceKm, avgHr, maxHr, calories
    }
}

private struct ExportedSettings: Encodable {
    let defaultLthr: Double
    let lthrByDiscipline: [String: Double]
}

private struct ExportedPlan: Encodable {
    struct Week: Encodable {
        let id: String
        let days: [[Workout]]
        let done: [Bool]
    }

    struct Workout: Encodable {
        let id: String
        let discipline: String
        let title: String
        let note: String
        let distanceKm: Double?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(discipline, forKey: .discipline)
            try container.encode(title, forKey: .title)
            try container.encode(note, forKey: .note)
            try container.encode(distanceKm, forKey: .distanceKm)
        }

        enum CodingKeys: String, CodingKey {
            case id, discipline, title, note, distanceKm
        }
    }

    let id: String
    let name: String
    let startMonday: String?
    let weeks: [Week]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startMonday, forKey: .startMonday)
        try container.encode(weeks, forKey: .weeks)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, startMonday, weeks
    }
}

private struct ExportedRace: Encodable {
    let distance: String
    let date: String?
    let targetSeconds: Double
    let weeklyHours: Double?
    let fromZero: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distance, forKey: .distance)
        try container.encode(date, forKey: .date)
        try container.encode(targetSeconds, forKey: .targetSeconds)
        try container.encode(weeklyHours, forKey: .weeklyHours)
        try container.encode(fromZero, forKey: .fromZero)
    }

    enum CodingKeys: String, CodingKey {
        case distance, date, targetSeconds, weeklyHours, fromZero
    }
}
