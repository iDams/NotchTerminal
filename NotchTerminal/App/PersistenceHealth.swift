import Foundation
import Combine

@MainActor
final class PersistenceHealth: ObservableObject {
    enum State: Equatable {
        case available
        case unavailable(details: String)
    }

    static let shared = PersistenceHealth()

    @Published private(set) var state: State = .available

    var isAvailable: Bool {
        if case .available = state {
            return true
        }
        return false
    }

    var failureDetails: String? {
        guard case let .unavailable(details) = state else { return nil }
        return details
    }

    func markAvailable() {
        state = .available
    }

    func markUnavailable(error: Error) {
        markUnavailable(details: Self.userFacingDetails(for: error))
    }

    func markUnavailable(details: String) {
        let sanitized = details.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .unavailable(details: sanitized.isEmpty ? Self.fallbackDetails : sanitized)
    }

    static func userFacingDetails(for error: Error) -> String {
        let sanitized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallbackDetails : sanitized
    }

    private static let fallbackDetails = "Unknown SwiftData error."
}
