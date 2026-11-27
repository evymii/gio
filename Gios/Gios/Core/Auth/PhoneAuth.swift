import FirebaseAuth
import FirebaseCore
import Foundation

/// Phone sign-in through Firebase Auth: send an SMS code, then confirm it.
/// The result is a Firebase ID token, which Gapi trades for its own session.
enum PhoneAuth {
    enum Failure: LocalizedError {
        case notConfigured
        var errorDescription: String? { "Phone sign-in isn't set up in this build (GoogleService-Info.plist is missing)." }
    }

    /// Mongolia by default; the user types the 8-digit local number.
    static let defaultCountryCode = "+976"

    /// "+976 9999-9999" → "+97699999999"
    static func e164(_ raw: String, countryCode: String = defaultCountryCode) -> String {
        let digits = raw.filter(\.isNumber)
        return raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") ? "+" + digits : countryCode + digits
    }

    /// Step 1: Firebase sends the SMS (or accepts a console test number). Returns a verification ID for step 2.
    static func sendCode(to phone: String) async throws -> String {
        guard FirebaseApp.app() != nil else { throw Failure.notConfigured }
        return try await PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil)
    }

    /// Step 2: sign in to Firebase with the code and return a fresh ID token.
    static func confirm(verificationID: String, code: String) async throws -> String {
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        let result = try await Auth.auth().signIn(with: credential)
        return try await result.user.getIDToken()
    }

    static func signOut() {
        guard FirebaseApp.app() != nil else { return }
        try? Auth.auth().signOut()
    }

    /// Firebase's error codes → short, human messages.
    static func message(for error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) else { return error.localizedDescription }
        switch code {
        case .invalidPhoneNumber, .missingPhoneNumber: return "That phone number doesn't look right."
        case .invalidVerificationCode: return "Wrong code. Check the SMS and try again."
        case .sessionExpired, .invalidVerificationID: return "The code expired. Send a new one."
        case .tooManyRequests, .quotaExceeded: return "Too many tries. Wait a bit and try again."
        case .networkError: return "No connection. Check your internet and try again."
        default: return error.localizedDescription
        }
    }
}
