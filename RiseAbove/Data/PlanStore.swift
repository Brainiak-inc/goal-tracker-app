import Foundation
import Observation
import TrainingKit

@Observable
final class PlanStore {
    private(set) var book = PlanBook()

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "plans.json")) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(PlanBook.self, from: data) {
            book = stored
        }
    }

    static let autoCheckKey = "autoCheckPlan"

    func applyActuals(_ activities: [Activity], calendar: Calendar) {
        var updated = book
        guard updated.applyActuals(activities, calendar: calendar) > 0 else { return }
        perform { $0 = updated }
    }

    func perform(_ change: (inout PlanBook) -> Void) {
        change(&book)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(book).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Saving plans failed: \(error)")
        }
    }
}
