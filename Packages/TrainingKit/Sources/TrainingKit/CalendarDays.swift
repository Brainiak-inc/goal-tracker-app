import Foundation

extension Calendar {
    public func monday(of date: Date) -> Date {
        let day = startOfDay(for: date)
        let weekday = component(.weekday, from: day)
        let offset = (weekday + 5) % 7
        return self.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    func adding(days: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: days, to: date) ?? date
    }
}

func jsRound(_ value: Double) -> Double {
    (value + 0.5).rounded(.down)
}
