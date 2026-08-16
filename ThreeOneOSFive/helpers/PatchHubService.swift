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
    /// Tổng thời lượng key tính theo NGÀY (key 1d, 7d, 30d, ...). Server trả
    /// `durationDays: 0` hoặc `null` khi key ngắn hạn dưới 1 ngày.
    let durationDays: Int?
    /// Optional: tổng thời lượng key tính theo GIỜ. Server nên trả cho key
    /// ngắn hạn (1h, 2h, 6h, 12h). Khi present, client ưu tiên dùng thay cho
    /// `durationDays` để countdown hiển thị chính xác "X giờ Y phút".
    let durationHours: Int?
    /// Optional: tổng thời lượng key tính theo PHÚT. Dùng cho key rất ngắn
    /// (< 1h) — server có thể trả `durationMinutes: 30` chẳng hạn.
    let durationMinutes: Int?
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
    case buildMissing
    case buildRevoked
    case buildUnknown

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
        case .buildMissing: return "Phiên bản chưa được đăng ký. Liên hệ admin"
        case .buildRevoked: return "Đã có phiên bản mới. Vui lòng liên hệ admin cập nhật bản mới!"
        case .buildUnknown: return "Đã có phiên bản mới. Vui lòng liên hệ admin cập nhật bản mới!"
        }
    }
}

enum PatchHubError: Error {
    case invalidResponse
    case checksumMismatch
}

enum PatchHubService {
    // MARK: - Obfuscated constants
    // baseURL được mã hóa XOR với key để tránh lộ server khi `strings` trên IPA.
    // KHÔNG phải crypto thật — chỉ là rào cản static analysis. Key XOR đặt ngay
    // trong source cố ý; mục tiêu là KHÔNG xuất hiện plaintext URL trong binary.
    private static let baseURLBytes: [UInt8] = [
        0xCF, 0x2F, 0x4A, 0xE1, 0xBF, 0x75, 0x3D, 0xA7,
        0xA0, 0x62, 0x2E, 0x92, 0xFE, 0x44, 0x18, 0xB8,
        0x4B, 0xDB, 0x18, 0xC6, 0x72, 0xFA, 0x3E, 0x9F,
        0x33, 0x7C, 0xB1, 0x50, 0x02, 0xA8, 0xD1, 0xE3
    ]
    private static let baseURLKey: [UInt8] = [
        0xA7, 0x5B, 0x3E, 0x91, 0xCC, 0x4F, 0x12, 0x88,
        0xD3, 0x07, 0x5C, 0xE4, 0x9B, 0x36, 0x71, 0xC8,
        0x2A, 0xF5, 0x68, 0xB4, 0x1D, 0x82, 0x47, 0xE9,
        0x5A, 0x0C, 0x9F, 0x33, 0x6E, 0xC1, 0xB2, 0x88
    ]
    static let baseURL: URL = {
        let host = Obfuscated.decode(baseURLBytes, key: baseURLKey)
        return URL(string: host)!
    }()

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
            "deviceSerial": deviceSerial,
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier
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
            "deviceSerial": deviceSerial,
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier
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
        case "build_missing": return .buildMissing
        case "build_revoked": return .buildRevoked
        case "build_unknown": return .buildUnknown
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
