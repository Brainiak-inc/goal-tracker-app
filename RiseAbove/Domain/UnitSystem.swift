import Foundation

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    static let storageKey = "unitSystem"

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }
}
