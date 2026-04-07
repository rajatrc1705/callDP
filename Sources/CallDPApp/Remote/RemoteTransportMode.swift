import Foundation

enum RemoteTransportMode: String, CaseIterable, Identifiable {
    case loopback
    case network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loopback:
            return "Loopback"
        case .network:
            return "Network"
        }
    }
}
