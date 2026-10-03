import Foundation

public struct GarminImport: Sendable {
    public let activities: [Activity]
    public let skipped: Int
}

public enum GarminCSV {
    static let minimumDuration: TimeInterval = 60

    public static func parse(_ text: String, timeZone: TimeZone = .current) -> GarminImport {
        let rows = rows(in: text)
        guard let header = rows.first else { return GarminImport(activities: [], skipped: 0) }

        var columns: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            columns[name.trimmingCharacters(in: .whitespaces)] = index
        }
        func cell(_ row: [String], _ name: String) -> String? {
            guard let index = columns[name], index < row.count else { return nil }
            return row[index].trimmingCharacters(in: .whitespaces)
        }

        var activities: [Activity] = []
        var skipped = 0
        for row in rows.dropFirst() {
            guard let start = date(cell(row, "Date"), timeZone: timeZone),
                  let duration = duration(cell(row, "Time")),
                  duration >= minimumDuration else {
                skipped += 1
                continue
            }
            let type = cell(row, "Activity Type") ?? "Unknown"
            let discipline = Discipline(garminType: type)
            let distance = number(cell(row, "Distance")).map { discipline == .swim ? $0 : $0 * 1000 }
            activities.append(Activity(
                start: start,
                discipline: discipline,
                sourceType: type,
                title: cell(row, "Title") ?? type,
                duration: duration,
                distance: distance,
                averageHeartRate: number(cell(row, "Avg HR")),
                maxHeartRate: number(cell(row, "Max HR")),
                calories: number(cell(row, "Calories")),
                elevationGain: number(cell(row, "Total Ascent"))
            ))
        }
        activities.sort { $0.start < $1.start }
        return GarminImport(activities: activities, skipped: skipped)
    }

    static func rows(in text: String) -> [[String]] {
        var source = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if source.hasPrefix("\u{FEFF}") {
            source.removeFirst()
        }
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var scalars = source.unicodeScalars.makeIterator()
        var pending = scalars.next()

        while let scalar = pending {
            pending = scalars.next()
            if inQuotes {
                if scalar == "\"" {
                    if pending == "\"" {
                        field.unicodeScalars.append("\"")
                        pending = scalars.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(scalar)
                }
            } else if scalar == "\"" {
                inQuotes = true
            } else if scalar == "," {
                row.append(field)
                field = ""
            } else if scalar == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.unicodeScalars.append(scalar)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    static func number(_ raw: String?) -> Double? {
        guard let raw, !raw.isEmpty, raw != "--" else { return nil }
        let cleaned = raw.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "'", with: "")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    static func duration(_ raw: String?) -> TimeInterval? {
        guard let raw, !raw.isEmpty, raw != "--" else { return nil }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map { Double($0) ?? 0 }
        guard (1...3).contains(parts.count) else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return (seconds * 1000).rounded() / 1000
    }

    static func date(_ raw: String?, timeZone: TimeZone) -> Date? {
        guard let raw, !raw.isEmpty, raw != "--" else { return nil }
        let text = raw.replacingOccurrences(of: "T", with: " ")
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }
}
