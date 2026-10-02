import Foundation

public enum Sport: String, Codable, CaseIterable, Sendable {
    case run
    case bike
    case swim
    case triathlon

    public var disciplines: [Discipline] {
        switch self {
        case .run: [.run]
        case .bike: [.bike]
        case .swim: [.swim]
        case .triathlon: Discipline.triathlon
        }
    }
}

public struct SportProfile: Hashable, Sendable, RawRepresentable {
    public static let storageKey = "sportProfile"
    public static let triathlon = SportProfile(sports: [.triathlon])
    public static let empty = SportProfile(unchecked: [])

    public private(set) var sports: Set<Sport>

    public init(sports: Set<Sport>) {
        self.sports = sports.isEmpty ? [.triathlon] : sports
    }

    private init(unchecked sports: Set<Sport>) {
        self.sports = sports
    }

    public init?(rawValue: String) {
        let sports = Set(rawValue.split(separator: ",").compactMap { Sport(rawValue: String($0)) })
        guard !sports.isEmpty else { return nil }
        self.sports = sports
    }

    public var rawValue: String {
        Sport.allCases.filter(sports.contains).map(\.rawValue).joined(separator: ",")
    }

    public var isEmpty: Bool {
        sports.isEmpty
    }

    public var isTriathlon: Bool {
        sports.contains(.triathlon)
    }

    public var disciplines: [Discipline] {
        let selected = Set(sports.flatMap(\.disciplines))
        return Discipline.triathlon.filter(selected.contains)
    }

    public var single: Discipline? {
        let disciplines = disciplines
        return disciplines.count == 1 ? disciplines[0] : nil
    }

    public var adherenceTracks: [AdherenceTrack] {
        guard disciplines.count > 1 else { return [.general] }
        return [.general] + disciplines.compactMap { AdherenceTrack(rawValue: $0.rawValue) }
    }

    public func isSelected(_ sport: Sport) -> Bool {
        sports.contains(sport)
    }

    public func isIncludedInTriathlon(_ sport: Sport) -> Bool {
        sport != .triathlon && isTriathlon
    }

    public mutating func toggle(_ sport: Sport, allowsEmpty: Bool = false) {
        if sport == .triathlon {
            if isTriathlon {
                sports.remove(.triathlon)
                if sports.isEmpty, !allowsEmpty {
                    sports = [.swim, .bike, .run]
                }
            } else {
                sports.insert(.triathlon)
            }
            return
        }
        guard !isTriathlon else { return }
        if sports.contains(sport) {
            guard sports.count > 1 || allowsEmpty else { return }
            sports.remove(sport)
        } else {
            sports.insert(sport)
        }
    }
}
