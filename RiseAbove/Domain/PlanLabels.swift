import Foundation
import TrainingKit

extension Calendar {
    func weekdayName(_ dayIndex: Int) -> String {
        let symbols = standaloneWeekdaySymbols
        return symbols[(dayIndex + 1) % 7].capitalized(with: locale ?? .current)
    }
}

extension TrainingPlan {
    func weekTitle(_ index: Int, calendar: Calendar) -> String {
        guard let start = weekStart(index, calendar: calendar),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return String(localized: "Week \(index + 1)")
        }
        let format = Date.FormatStyle.dateTime.day().month(.wide)
        return "\(start.formatted(format)) — \(end.formatted(format))"
    }

    func dayTitle(_ day: Int, ofWeek index: Int, calendar: Calendar) -> String {
        let name = calendar.weekdayName(day)
        guard let date = self.day(day, ofWeek: index, calendar: calendar) else { return name }
        return "\(name), \(date.formatted(.dateTime.day().month(.wide)))"
    }
}
