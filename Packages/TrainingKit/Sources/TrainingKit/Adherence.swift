import Foundation

public enum AdherenceStatus: String, Codable, CaseIterable, Sendable {
    case full
    case partial
    case missed
}

public struct DayMark: Codable, Hashable, Sendable {
    public var status: AdherenceStatus
    public var comment: String

    public init(status: AdherenceStatus, comment: String = "") {
        self.status = status
        self.comment = comment
    }
}

public enum AdherenceTrack: String, CaseIterable, Sendable {
    case general
    case swim
    case bike
    case run
}

public struct AdherenceBook: Codable, Hashable, Sendable {
    public var marks: [String: [String: DayMark]]

    public init(marks: [String: [String: DayMark]] = [:]) {
        self.marks = marks
    }

    public init(from decoder: Decoder) throws {
        marks = try decoder.singleValueContainer().decode([String: [String: DayMark]].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(marks)
    }

    public var isEmpty: Bool {
        marks.values.allSatisfy(\.isEmpty)
    }

    public func mark(_ track: AdherenceTrack, on day: Date, calendar: Calendar) -> DayMark? {
        marks[track.rawValue]?[Self.key(day, calendar: calendar)]
    }

    public mutating func setMark(_ mark: DayMark?, _ track: AdherenceTrack, on day: Date, calendar: Calendar) {
        let key = Self.key(day, calendar: calendar)
        var trackMarks = marks[track.rawValue] ?? [:]
        if var mark {
            mark.comment = mark.comment.trimmingCharacters(in: .whitespacesAndNewlines)
            trackMarks[key] = mark
        } else {
            trackMarks.removeValue(forKey: key)
        }
        marks[track.rawValue] = trackMarks
    }

    public mutating func merge(_ other: AdherenceBook) {
        for (track, days) in other.marks {
            marks[track, default: [:]].merge(days) { _, imported in imported }
        }
    }

    public func counts(_ track: AdherenceTrack, year: Int) -> [AdherenceStatus: Int] {
        var result: [AdherenceStatus: Int] = [:]
        for (key, mark) in marks[track.rawValue] ?? [:] where key.hasPrefix("\(year)-") {
            result[mark.status, default: 0] += 1
        }
        return result
    }

    static func key(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

public struct CalendarWeek: Hashable, Sendable {
    public struct Cell: Hashable, Sendable {
        public let date: Date
        public let isInYear: Bool
    }

    public let cells: [Cell]
    public let startsMonth: Date?
}

public enum YearGrid {
    public static func weeks(year: Int, calendar: Calendar) -> [CalendarWeek] {
        guard let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let last = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else { return [] }
        let gridStart = calendar.monday(of: first)
        let gridEnd = calendar.adding(days: 6, to: calendar.monday(of: last))
        var weeks: [CalendarWeek] = []
        var cursor = gridStart
        while cursor <= gridEnd {
            let cells = (0..<7).map { offset -> CalendarWeek.Cell in
                let date = calendar.adding(days: offset, to: cursor)
                return CalendarWeek.Cell(date: date, isInYear: calendar.component(.year, from: date) == year)
            }
            let startsMonth = cells.first { $0.isInYear && calendar.component(.day, from: $0.date) == 1 }?.date
            weeks.append(CalendarWeek(cells: cells, startsMonth: startsMonth))
            cursor = calendar.adding(days: 7, to: cursor)
        }
        return weeks
    }
}
