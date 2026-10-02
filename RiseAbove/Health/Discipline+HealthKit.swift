import HealthKit
import TrainingKit

extension Discipline {
    init(workoutType: HKWorkoutActivityType) {
        switch workoutType {
        case .running:
            self = .run
        case .cycling, .handCycling:
            self = .bike
        case .swimming:
            self = .swim
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            self = .strength
        default:
            self = .other
        }
    }
}

extension HKWorkoutActivityType {
    var identifier: String {
        switch self {
        case .running: "running"
        case .cycling: "cycling"
        case .handCycling: "hand-cycling"
        case .swimming: "swimming"
        case .walking: "walking"
        case .hiking: "hiking"
        case .traditionalStrengthTraining: "strength-training"
        case .functionalStrengthTraining: "functional-strength-training"
        case .coreTraining: "core-training"
        case .yoga: "yoga"
        case .pilates: "pilates"
        case .swimBikeRun: "multisport"
        default: "type-\(rawValue)"
        }
    }
}
