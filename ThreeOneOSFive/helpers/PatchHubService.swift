import CryptoKit
import Foundation

struct RemotePatchSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let version: String
    let fileName: String
    let sizeBytes: Int64
    let sha256: String
    let createdAt: String
    let gameId: String?
}

struct RemoteGameSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let bundleID: String
    let bannerColor: String
    let iconPath: String?
    let createdAt: String

    var iconURL: URL? {
        guard let iconPath else { return nil }
        return PatchHubService.baseURL.appendingPathComponent(String(iconPath.dropFirst()))
    }
}

/// Server response for POST /api/activate and POST /api/keys/verify.
struct RemoteKeyStatus: Decodable, Equatable {
    let ok: Bool
    let reason: String?
    let expiresAt: String?
    let activatedAt: String?
    let durationDays: Int?
    let remainingSlots: Int?
    let firstActivation: Bool?
    let alreadyBound: Bool?
    let maxDevices: Int?
}

/// User-friendly failure reasons for key verification / activation. Maps to
/// Vietnamese messages surfaced to the user from the toggle flow.
enum LicenseKeyError: Error, LocalizedError {
    case invalidResponse
    case keyNotFound
    case revoked
    case expired
    case notActivated
    case deviceLimitReached(maxDevices: Int?)
    case deviceNotBound
    case internalError
    case missingKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Phản hồi từ máy chủ không hợp lệ"
        case .keyNotFound: return "Key không tồn tại. Vui lòng kiểm tra lại"
        case .revoked: return "Key đã bị khoá. Vui lòng liên hệ admin"
        case .expired: return "Key đã hết hạn. Vui lòng gia hạn"
        case .notActivated: return "Key chưa được kích hoạt"
        case .deviceLimitReached(let n): return n == nil
            ? "Key đã đạt giới hạn thiết bị"
            : "Key đã đạt giới hạn \(n!) thiết bị"
        case .deviceNotBound: return "Thiết bị chưa được bind với key. Vui lòng nhập lại key"
        case .internalError: return "Lỗi máy chủ. Vui lòng thử lại sau"
        case .missingKey: return "Chưa nhập key"
        }
    }
}

enum PatchHubError: Error {
    case invalidResponse
    case checksumMismatch
}

enum PatchHubService {
    static let baseURL = URL(string: "https://serveripa.proxyvip.click")!

    static func fetchGames() async throws -> [RemoteGameSummary] {
        let url = baseURL.appendingPathComponent("api/games")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let games: [RemoteGameSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).games
    }

    static func fetchPatches() async throws -> [RemotePatchSummary] {
        let url = baseURL.appendingPathComponent("api/patches")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let patches: [RemotePatchSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).patches
    }

    static func downloadPatch(_ summary: RemotePatchSummary) async throws -> URL {
        let url = baseURL.appendingPathComponent("api/patches/\(summary.id)/download")
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.invalidResponse
        }
        guard try digest(of: tempURL) == summary.sha256.lowercased() else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.checksumMismatch
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("3105")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// Activates a license key on the server, binding the current device. Returns
    /// the parsed response on success, throws `LicenseKeyError` on any failure.
    static func activate(key: String, deviceSerial: String) async throws -> RemoteKeyStatus {
        let url = baseURL.appendingPathComponent("api/activate")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12
        let body: [String: Any] = [
            "key": key,
            "deviceSerial": deviceSerial
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        return try parseKeyResponse(data: data, response: response, defaultReason: "invalid_response")
    }

    /// Verifies the key is still active and bound to this device. Never mutates
    /// state on the server. Used before every patch toggle.
    static func verifyKey(key: String, deviceSerial: String) async throws -> RemoteKeyStatus {
        let url = baseURL.appendingPathComponent("api/keys/verify")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        let body: [String: Any] = [
            "key": key,
            "deviceSerial": deviceSerial
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        return try parseKeyResponse(data: data, response: response, defaultReason: "invalid_response")
    }

    private static func parseKeyResponse(
        data: Data,
        response: URLResponse,
        defaultReason: String
    ) throws -> RemoteKeyStatus {
        guard let http = response as? HTTPURLResponse else {
            throw LicenseKeyError.invalidResponse
        }
        // Server may return non-2xx with a JSON body containing `reason`; decode
        // the body in any case so we surface the real failure to the caller.
        let decoded = (try? JSONDecoder().decode(RemoteKeyStatus.self, from: data))
        if (200...299).contains(http.statusCode) {
            if let decoded, decoded.ok {
                return decoded
            }
            throw LicenseKeyError.invalidResponse
        }
        let reason = decoded?.reason ?? defaultReason
        throw mapReason(reason, decoded: decoded)
    }

    private static func mapReason(_ reason: String, decoded: RemoteKeyStatus?) -> LicenseKeyError {
        switch reason {
        case "key_not_found": return .keyNotFound
        case "revoked": return .revoked
        case "expired": return .expired
        case "not_activated": return .notActivated
        case "device_limit_reached":
            return .deviceLimitReached(maxDevices: decoded?.maxDevices)
        case "device_not_bound": return .deviceNotBound
        case "internal_error": return .internalError
        case "missing_key": return .missingKey
        default: return .invalidResponse
        }
    }

    private static func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize()).map { String(format: "%02x", $0) }.joined()
    }
}
