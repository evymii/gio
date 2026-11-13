import Foundation

/// Everything that can go wrong talking to Gapi, with user-readable messages.
enum APIError: Error, Equatable, LocalizedError {
    case server(status: Int, code: String, message: String)
    case unreachable(String)
    case decoding(String)
    case sessionExpired
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .server(_, _, message): return message
        case let .unreachable(reason): return "Can't reach the server — \(reason)"
        case let .decoding(reason): return "Unexpected response from server — \(reason)"
        case .sessionExpired: return "Your session expired. Please log in again."
        case .invalidResponse: return "Invalid response from server"
        }
    }

    var code: String? { if case let .server(_, code, _) = self { return code } else { return nil } }
}
