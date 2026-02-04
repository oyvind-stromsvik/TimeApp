import Foundation

enum MenuBarDurationMode: String, CaseIterable, Identifiable {
    case activeOnly
    case sameNameToday
    case sameNameAll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .activeOnly:
            return "Current task"
        case .sameNameToday:
            return "Same name today"
        case .sameNameAll:
            return "Same name all time"
        }
    }
}
