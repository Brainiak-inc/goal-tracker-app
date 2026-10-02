import Foundation

public enum Discipline: String, Codable, CaseIterable, Sendable {
    case swim
    case bike
    case run
    case strength
    case other

    public static let triathlon: [Discipline] = [.swim, .bike, .run]

    public var isTriathlon: Bool {
        Self.triathlon.contains(self)
    }

    public init(garminType: String) {
        let type = garminType.lowercased()
        if type.contains("swim") {
            self = .swim
        } else if type.contains("cycl") || type.contains("biking") || type.contains("bike") {
            self = .bike
        } else if type.contains("run") {
            self = .run
        } else if type.contains("strength") {
            self = .strength
        } else {
            self = .other
        }
    }
}
