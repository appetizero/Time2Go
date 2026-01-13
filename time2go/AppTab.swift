import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case timer
    case stats
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timer:    return "figure.walk" 
        case .stats:    return "hourglass"
        case .settings: return "gearshape"
        }
    }

    var filledIcon: String {
        icon
    }
}
