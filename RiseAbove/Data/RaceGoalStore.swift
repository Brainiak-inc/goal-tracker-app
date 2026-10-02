import Foundation
import Observation
import TrainingKit

@Observable
final class RaceGoalStore {
    private(set) var config: RaceConfig?

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "race.json")) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL) {
            config = try? JSONDecoder().decode(RaceConfig.self, from: data)
        }
    }

    func save(_ config: RaceConfig) {
        self.config = config
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(config).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Saving the race goal failed: \(error)")
        }
    }

    func clear() {
        config = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
