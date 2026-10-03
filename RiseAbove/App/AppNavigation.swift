import Observation
import TrainingKit

enum AppTab: Hashable {
    case overview
    case readiness
    case disciplines
    case plan
}

@Observable
final class AppNavigation {
    var tab: AppTab = .overview
    var requestedDiscipline: Discipline?

    func show(_ discipline: Discipline) {
        requestedDiscipline = discipline
        tab = .disciplines
    }
}
