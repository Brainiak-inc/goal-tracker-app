import Foundation
import TrainingKit

extension Discipline {
    var title: LocalizedStringResource {
        switch self {
        case .swim: "Swim"
        case .bike: "Bike"
        case .run: "Run"
        case .strength: "Strength"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .swim: "figure.pool.swim"
        case .bike: "figure.outdoor.cycle"
        case .run: "figure.run"
        case .strength: "figure.strengthtraining.traditional"
        case .other: "figure.mixed.cardio"
        }
    }
}
