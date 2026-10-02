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
}
