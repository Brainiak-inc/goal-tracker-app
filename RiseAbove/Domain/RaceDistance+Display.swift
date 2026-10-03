import Foundation
import TrainingKit

extension RacePreset {
    var title: LocalizedStringResource {
        switch self {
        case .sprint: "Sprint"
        case .olympic: "Olympic distance"
        case .half: "Half distance"
        case .full: "Full distance"
        case .run5k: "5 km"
        case .run10k: "10 km"
        case .halfMarathon: "Half marathon"
        case .marathon: "Marathon"
        case .bike50: "50 km"
        case .bike100: "100 km"
        case .bike160: "160 km"
        case .swim1500: "1.5 km"
        case .swim3k: "3 km"
        case .swim5k: "5 km"
        case .swim10k: "10 km"
        }
    }
}

extension RaceConfig {
    func title(units: UnitSystem) -> String {
        if let timeLimit {
            let hours = Int((timeLimit / 3600).rounded())
            return String(localized: "\(String(localized: distance.sport.title)) · \(String(localized: "\(hours) hours"))")
        }
        if let preset = distance.preset {
            if distance.sport == .triathlon {
                return String(localized: preset.title)
            }
            return String(localized: "\(String(localized: distance.sport.title)) · \(String(localized: preset.title))")
        }
        let legs = distance.disciplines
            .map { Formatting.distance(distance.leg(for: $0), discipline: $0, units: units) }
            .joined(separator: " · ")
        return String(localized: "\(String(localized: distance.sport.title)) · \(legs)")
    }

    func details(units: UnitSystem) -> String {
        let date = raceDay.map { $0.formatted(.dateTime.day().month(.wide).year()) } ?? String(localized: "date not set")
        if isTimed {
            guard hasGoalDistance, let leg = distance.disciplines.first else { return date }
            return [date, String(localized: "goal \(Formatting.distance(distance.leg(for: leg), discipline: leg, units: units))")].joined(separator: " · ")
        }
        return [date, String(localized: "goal \(Formatting.raceTime(targetTime))")].joined(separator: " · ")
    }

    func summary(units: UnitSystem) -> String {
        [title(units: units), details(units: units)].joined(separator: " · ")
    }
}

struct InputUnit {
    let discipline: Discipline
    let units: UnitSystem

    var metersPerUnit: Double {
        switch (discipline == .swim, units) {
        case (true, .metric): 1
        case (true, .imperial): 0.9144
        case (false, .metric): 1000
        case (false, .imperial): 1609.344
        }
    }

    var name: String {
        let unit: UnitLength = switch (discipline == .swim, units) {
        case (true, .metric): .meters
        case (true, .imperial): .yards
        case (false, .metric): .kilometers
        case (false, .imperial): .miles
        }
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .long
        return formatter.string(from: unit)
    }

    func text(_ meters: Double) -> String {
        (meters / metersPerUnit).formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    func meters(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value * metersPerUnit
    }
}
