import Foundation
import TrainingKit

extension Sport {
    var title: LocalizedStringResource {
        switch self {
        case .run: "Running"
        case .bike: "Cycling"
        case .swim: "Swimming"
        case .triathlon: "Triathlon"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .run: "Volume, pace, and training load"
        case .bike: "Volume, speed, and training load"
        case .swim: "Pool and open water: volume, pace, and training load"
        case .triathlon: "All three disciplines and race readiness"
        }
    }
}

extension SportProfile {
    var summary: String {
        let names = Sport.allCases
            .filter { isTriathlon ? $0 == .triathlon : isSelected($0) }
            .map { String(localized: $0.title) }
            .formatted(.list(type: .and))
            .lowercased()
        return names.prefix(1).uppercased() + names.dropFirst()
    }
}
