import Foundation
import TrainingKit

enum Formatting {
    static func distance(_ meters: Double, discipline: Discipline, units: UnitSystem) -> String {
        if discipline == .swim {
            let unit: UnitLength = units == .metric ? .meters : .yards
            let value = Measurement(value: meters, unit: UnitLength.meters).converted(to: unit).value.rounded()
            return Measurement(value: value, unit: unit).formatted(
                .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
            )
        }
        let unit: UnitLength = units == .metric ? .kilometers : .miles
        return Measurement(value: meters, unit: UnitLength.meters).converted(to: unit).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1)))
        )
    }

    static func pace(distance meters: Double, duration: TimeInterval, discipline: Discipline, units: UnitSystem) -> String? {
        guard meters > 0, duration > 0 else { return nil }
        switch discipline {
        case .bike:
            let speed = Measurement(value: meters / duration, unit: UnitSpeed.metersPerSecond)
                .converted(to: units == .metric ? .kilometersPerHour : .milesPerHour)
            return speed.formatted(
                .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1)))
            )
        case .swim:
            let block = units == .metric ? 100.0 : 91.44
            let clock = minutesAndSeconds(duration / meters * block)
            return units == .metric
                ? String(localized: "\(clock) per 100 m")
                : String(localized: "\(clock) per 100 yd")
        default:
            let block = units == .metric ? 1000.0 : 1609.344
            let clock = minutesAndSeconds(duration / meters * block)
            return units == .metric
                ? String(localized: "\(clock) per km")
                : String(localized: "\(clock) per mile")
        }
    }

    static func minutesAndSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return "\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }

    static func signed(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))
    }
}

extension Trend {
    var arrow: String {
        switch self {
        case .up: "▲"
        case .flat: "→"
        case .down: "▼"
        }
    }
}

extension FormZone {
    var title: LocalizedStringResource {
        switch self {
        case .fresh: "fresh"
        case .neutral: "neutral"
        case .building: "building fitness"
        case .overreaching: "overreaching"
        }
    }
}
