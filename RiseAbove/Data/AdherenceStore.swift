import Foundation
import Observation
import TrainingKit

@Observable
final class AdherenceStore {
    private(set) var book = AdherenceBook()

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "adherence.json")) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(AdherenceBook.self, from: data) {
            book = stored
        }
    }

    func perform(_ change: (inout AdherenceBook) -> Void) {
        change(&book)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(book).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Saving the adherence calendar failed: \(error)")
        }
    }
}
