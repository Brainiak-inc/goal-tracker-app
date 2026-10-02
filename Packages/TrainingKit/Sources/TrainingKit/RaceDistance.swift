import Foundation

public enum RacePreset: String, Codable, CaseIterable, Sendable {
    case sprint
    case olympic
    case half
    case full
    case run5k
    case run10k
    case halfMarathon
    case marathon
    case bike50
    case bike100
    case bike160
    case swim1500
    case swim3k
    case swim5k
    case swim10k

    public var sport: Sport {
        switch self {
        case .sprint, .olympic, .half, .full: .triathlon
        case .run5k, .run10k, .halfMarathon, .marathon: .run
        case .bike50, .bike100, .bike160: .bike
        case .swim1500, .swim3k, .swim5k, .swim10k: .swim
        }
    }

    public var legs: [Discipline: Double] {
        switch self {
        case .sprint: [.swim: 750, .bike: 20_000, .run: 5_000]
        case .olympic: [.swim: 1_500, .bike: 40_000, .run: 10_000]
        case .half: [.swim: 1_900, .bike: 90_000, .run: 21_100]
        case .full: [.swim: 3_800, .bike: 180_000, .run: 42_200]
        case .run5k: [.run: 5_000]
        case .run10k: [.run: 10_000]
        case .halfMarathon: [.run: 21_100]
        case .marathon: [.run: 42_200]
        case .bike50: [.bike: 50_000]
        case .bike100: [.bike: 100_000]
        case .bike160: [.bike: 160_000]
        case .swim1500: [.swim: 1_500]
        case .swim3k: [.swim: 3_000]
        case .swim5k: [.swim: 5_000]
        case .swim10k: [.swim: 10_000]
        }
    }

    public var cutoff: TimeInterval {
        switch self {
        case .sprint: 2.5 * 3600
        case .olympic: 4.5 * 3600
        case .half: 8.5 * 3600
        case .full: 17 * 3600
        case .run5k: 45 * 60
        case .run10k: 1.5 * 3600
        case .halfMarathon: 3 * 3600
        case .marathon: 6 * 3600
        case .bike50: 3 * 3600
        case .bike100: 6 * 3600
        case .bike160: 10 * 3600
        case .swim1500: 1 * 3600
        case .swim3k: 2 * 3600
        case .swim5k: 3.5 * 3600
        case .swim10k: 7 * 3600
        }
    }

    var transitionTime: TimeInterval {
        switch self {
        case .sprint: 4 * 60
        case .olympic: 6 * 60
        case .half: 8 * 60
        case .full: 12 * 60
        default: 0
        }
    }

    public static func presets(for sport: Sport) -> [RacePreset] {
        allCases.filter { $0.sport == sport }
    }
}

public struct RaceDistance: Hashable, Sendable {
    public static let full = RaceDistance(preset: .full)
    public static let half = RaceDistance(preset: .half)

    public let sport: Sport
    public let preset: RacePreset?
    private let lengths: [Discipline: Double]

    public init(preset: RacePreset) {
        sport = preset.sport
        self.preset = preset
        lengths = preset.legs
    }

    public init(sport: Sport, legs: [Discipline: Double]) {
        self.sport = sport
        preset = nil
        var lengths: [Discipline: Double] = [:]
        for discipline in sport.disciplines {
            lengths[discipline] = max(0, legs[discipline] ?? 0)
        }
        self.lengths = lengths
    }

    public var isCustom: Bool {
        preset == nil
    }

    public var isValid: Bool {
        disciplines.allSatisfy { leg(for: $0) > 0 }
    }

    public var isWebCompatible: Bool {
        preset == .full || preset == .half
    }

    public var disciplines: [Discipline] {
        sport.disciplines
    }

    public func leg(for discipline: Discipline) -> Double {
        lengths[discipline] ?? 0
    }

    public var total: Double {
        disciplines.reduce(0) { $0 + leg(for: $1) }
    }

    public var cutoff: TimeInterval {
        if let preset {
            return preset.cutoff
        }
        let speed = RaceNorms.cutoffSpeed(sport: sport, total: total)
        return (total / speed + transitionTime).rounded()
    }

    var transitionTime: TimeInterval {
        if let preset {
            return preset.transitionTime
        }
        return sport == .triathlon ? 8 * 60 : 0
    }

    func target(for discipline: Discipline) -> (weekly: Double, longest: Double) {
        RaceNorms.target(sport: sport, discipline: discipline, length: leg(for: discipline))
    }

    func longestCap(for discipline: Discipline) -> Double? {
        RaceNorms.longestCap(sport: sport, discipline: discipline, length: leg(for: discipline))
    }

    func share(for discipline: Discipline) -> Double {
        guard sport == .triathlon else { return 1 }
        return RaceNorms.triathlonShare[discipline] ?? 0
    }
}

extension RaceDistance: Codable {
    private struct Custom: Codable {
        let sport: Sport
        let legs: [String: Double]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            guard let preset = RacePreset(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown race distance \(raw)")
            }
            self.init(preset: preset)
            return
        }
        let custom = try container.decode(Custom.self)
        var legs: [Discipline: Double] = [:]
        for (key, value) in custom.legs {
            if let discipline = Discipline(rawValue: key) {
                legs[discipline] = value
            }
        }
        self.init(sport: custom.sport, legs: legs)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let preset {
            try container.encode(preset.rawValue)
        } else {
            var legs: [String: Double] = [:]
            for discipline in disciplines {
                legs[discipline.rawValue] = leg(for: discipline)
            }
            try container.encode(Custom(sport: sport, legs: legs))
        }
    }
}

enum RaceNorms {
    struct Point {
        let length: Double
        let weekly: Double
        let longest: Double
        var cap: Double?
    }

    static let triathlonShare: [Discipline: Double] = [.swim: 0.14, .bike: 0.47, .run: 0.39]
    static let timedReferenceSpeed: [Discipline: Double] = [.run: 7_000 / 3600, .bike: 20_000 / 3600, .swim: 2_500 / 3600]

    static let triathlon: [Discipline: [Point]] = [
        .swim: [
            Point(length: 750, weekly: 2_000, longest: 800),
            Point(length: 1_500, weekly: 2_500, longest: 1_500),
            Point(length: 1_900, weekly: 3_000, longest: 1_900),
            Point(length: 3_800, weekly: 6_000, longest: 3_000)
        ],
        .bike: [
            Point(length: 20_000, weekly: 40_000, longest: 20_000),
            Point(length: 40_000, weekly: 60_000, longest: 35_000),
            Point(length: 90_000, weekly: 110_000, longest: 80_000),
            Point(length: 180_000, weekly: 180_000, longest: 120_000)
        ],
        .run: [
            Point(length: 5_000, weekly: 12_000, longest: 6_000),
            Point(length: 10_000, weekly: 18_000, longest: 10_000),
            Point(length: 21_100, weekly: 25_000, longest: 16_000),
            Point(length: 42_200, weekly: 40_000, longest: 28_000)
        ]
    ]

    static let single: [Discipline: [Point]] = [
        .swim: [
            Point(length: 1_500, weekly: 4_500, longest: 1_600, cap: 3_000),
            Point(length: 3_000, weekly: 7_000, longest: 2_500, cap: 5_000),
            Point(length: 5_000, weekly: 10_000, longest: 3_600, cap: 7_000),
            Point(length: 10_000, weekly: 17_000, longest: 6_000, cap: 12_000)
        ],
        .bike: [
            Point(length: 50_000, weekly: 65_000, longest: 40_000, cap: 80_000),
            Point(length: 100_000, weekly: 110_000, longest: 65_000, cap: 130_000),
            Point(length: 160_000, weekly: 150_000, longest: 85_000, cap: 180_000)
        ],
        .run: [
            Point(length: 5_000, weekly: 18_000, longest: 7_000, cap: 14_000),
            Point(length: 10_000, weekly: 24_000, longest: 9_000, cap: 18_000),
            Point(length: 21_100, weekly: 30_000, longest: 13_000, cap: 24_000),
            Point(length: 42_200, weekly: 40_000, longest: 21_000, cap: 35_000)
        ]
    ]

    static func points(sport: Sport, discipline: Discipline) -> [Point] {
        (sport == .triathlon ? triathlon : single)[discipline] ?? []
    }

    static func target(sport: Sport, discipline: Discipline, length: Double) -> (weekly: Double, longest: Double) {
        let points = points(sport: sport, discipline: discipline)
        let weekly = interpolate(points, at: length, \.weekly)
        let longest = interpolate(points, at: length, \.longest)
        return (max(0, weekly), max(0, longest))
    }

    static func longestCap(sport: Sport, discipline: Discipline, length: Double) -> Double? {
        let points = points(sport: sport, discipline: discipline)
        guard points.allSatisfy({ $0.cap != nil }) else { return nil }
        return interpolate(points, at: length) { $0.cap ?? 0 }
    }

    static func cutoffSpeed(sport: Sport, total: Double) -> Double {
        let points = RacePreset.presets(for: sport).map { preset in
            let distance = RaceDistance(preset: preset)
            return Point(length: distance.total, weekly: distance.total / (preset.cutoff - preset.transitionTime), longest: 0)
        }
        return max(0.1, interpolate(points, at: total, \.weekly))
    }

    static func interpolate(_ points: [Point], at length: Double, _ value: (Point) -> Double) -> Double {
        guard let first = points.first else { return 0 }
        if let exact = points.first(where: { $0.length == length }) {
            return value(exact)
        }
        guard points.count > 1, length > 0 else { return value(first) }
        let lower: Point
        let upper: Point
        if length < first.length {
            lower = points[0]
            upper = points[1]
        } else if let index = points.firstIndex(where: { $0.length > length }) {
            lower = points[index - 1]
            upper = points[index]
        } else {
            lower = points[points.count - 2]
            upper = points[points.count - 1]
        }
        let position = log(length / lower.length) / log(upper.length / lower.length)
        return value(lower) + (value(upper) - value(lower)) * position
    }
}
