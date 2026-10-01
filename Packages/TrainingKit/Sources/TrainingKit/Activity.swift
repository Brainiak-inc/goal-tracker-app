import Foundation

public struct Activity: Codable, Hashable, Sendable {
    public var start: Date
    public var discipline: Discipline
    public var sourceType: String
    public var title: String
    public var duration: TimeInterval
    public var distance: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var calories: Double?

    public init(
        start: Date,
        discipline: Discipline,
        sourceType: String,
        title: String,
        duration: TimeInterval,
        distance: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        calories: Double? = nil
    ) {
        self.start = start
        self.discipline = discipline
        self.sourceType = sourceType
        self.title = title
        self.duration = duration
        self.distance = distance
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.calories = calories
    }

    public var end: Date {
        start.addingTimeInterval(duration)
    }
}
