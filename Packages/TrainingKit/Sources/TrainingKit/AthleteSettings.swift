import Foundation

public struct AthleteSettings: Codable, Hashable, Sendable {
    public static let fallbackThresholdHeartRate: Double = 170

    public var thresholdHeartRate: Double
    public var thresholdHeartRateByDiscipline: [Discipline: Double]

    public init(
        thresholdHeartRate: Double = AthleteSettings.fallbackThresholdHeartRate,
        thresholdHeartRateByDiscipline: [Discipline: Double] = [:]
    ) {
        self.thresholdHeartRate = thresholdHeartRate
        self.thresholdHeartRateByDiscipline = thresholdHeartRateByDiscipline
    }

    public func thresholdHeartRate(for discipline: Discipline) -> Double {
        thresholdHeartRateByDiscipline[discipline] ?? thresholdHeartRate
    }
}
