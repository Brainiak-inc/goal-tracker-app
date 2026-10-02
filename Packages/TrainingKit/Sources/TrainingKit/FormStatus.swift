import Foundation

public enum FormZone: String, Sendable, CaseIterable {
    case fresh
    case neutral
    case building
    case overreaching

    public init(form: Double) {
        if form > 5 {
            self = .fresh
        } else if form >= -10 {
            self = .neutral
        } else if form >= -30 {
            self = .building
        } else {
            self = .overreaching
        }
    }
}

public struct FitnessSnapshot: Hashable, Sendable {
    public let fitness: Double
    public let form: Double
    public let fitnessTrend: Double

    public init(fitness: Double, form: Double, fitnessTrend: Double) {
        self.fitness = fitness
        self.form = form
        self.fitnessTrend = fitnessTrend
    }

    public init?(series: [LoadPoint]) {
        guard let last = series.last else { return nil }
        let trend = series.count >= 8 ? last.fitness - series[series.count - 8].fitness : 0
        self.init(fitness: last.fitness, form: last.form, fitnessTrend: trend)
    }
}
