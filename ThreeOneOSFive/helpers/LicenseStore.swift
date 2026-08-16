import Foundation

/// Lưu key + thông tin phiên đăng nhập vào UserDefaults. Chỉ lưu local — việc
/// xác thực thật sự vẫn phải qua server mỗi lần mở app.
final class LicenseStore: ObservableObject {

    static let shared = LicenseStore()

    @Published private(set) var savedKey: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var activatedAt: Date?
    @Published private(set) var durationDays: Int?

    private let keyDefaultsKey = "license.savedKey"
    private let expiresKey = "license.expiresAt"
    private let activatedKey = "license.activatedAt"
    private let durationKey = "license.durationDays"

    private init() {
        // Mỗi lần vào app đều bắt nhập lại: không đọc key từ UserDefaults khi
        // khởi động. Key hợp lệ chỉ tồn tại trong RAM trong phiên hiện tại; bản
        // lưu trên UserDefaults (nếu có) chỉ dùng để Logout/clear().
        // Riêng thời gian (expiresAt) đọc từ cache để footer vẫn đếm ngược chuẩn
        // thời gian còn lại thực của key, không bị reset khi user nhập lại key.
        self.savedKey = nil
        self.activatedAt = nil
        self.durationDays = nil
        if let stored = UserDefaults.standard.object(forKey: expiresKey) as? Double {
            self.expiresAt = Date(timeIntervalSince1970: stored)
        } else {
            self.expiresAt = nil
        }
    }

    var isSaved: Bool { (savedKey?.isEmpty == false) }

    /// Đọc các trường thời gian từ UserDefaults vào RAM mà KHÔNG gọi server.
    /// Dùng sau khi verifyKey OK để footer vẫn đếm ngược đúng thời gian thực
    /// còn lại của key (server không cần trả expiresAt trong verify).
    func restoreSession() {
        let d = UserDefaults.standard
        if let stored = d.object(forKey: expiresKey) as? Double {
            self.expiresAt = Date(timeIntervalSince1970: stored)
        }
        if let stored = d.object(forKey: activatedKey) as? Double {
            self.activatedAt = Date(timeIntervalSince1970: stored)
        }
        if let stored = d.object(forKey: durationKey) as? Int {
            self.durationDays = stored
        }
    }

    func save(key: String, status: RemoteKeyStatus) {
        let d = UserDefaults.standard
        d.set(key, forKey: keyDefaultsKey)
        var resolvedExpiresAt: Date?
        if let s = status.expiresAt, let date = ISO8601DateFormatter().date(from: s) {
            resolvedExpiresAt = date
        }
        var resolvedActivatedAt: Date?
        if let s = status.activatedAt, let date = ISO8601DateFormatter().date(from: s) {
            resolvedActivatedAt = date
        }
        // Fallback khi server không trả expiresAt: nếu có durationDays thì tính
        // từ activatedAt, hoặc từ thời điểm hiện tại. Đảm bảo footer luôn có
        // mốc đếm ngược, không phụ thuộc response shape.
        if resolvedExpiresAt == nil, let dur = status.durationDays, dur > 0 {
            let base = resolvedActivatedAt ?? Date()
            resolvedExpiresAt = base.addingTimeInterval(TimeInterval(dur) * 86_400)
        }
        // Bảo vệ thời gian còn lại thực của key: nếu local cache vẫn còn hạn
        // (expiresAt > now) thì GIỮ NGUYÊN, không ghi đè bằng expiresAt mới từ
        // activate. Tránh hiện tượng mỗi lần vào app phải nhập lại key → server
        // reset activatedAt → countdown chạy lại từ đầu.
        let storedExpires = d.object(forKey: expiresKey) as? Double
        let storedExpiresDate = storedExpires.map { Date(timeIntervalSince1970: $0) }
        let finalExpiresAt: Date? = {
            if let local = storedExpiresDate, local > Date() {
                return local
            }
            return resolvedExpiresAt
        }()
        if let date = finalExpiresAt {
            d.set(date.timeIntervalSince1970, forKey: expiresKey)
            self.expiresAt = date
        }
        if let date = resolvedActivatedAt {
            d.set(date.timeIntervalSince1970, forKey: activatedKey)
            self.activatedAt = date
        }
        if let dur = status.durationDays {
            d.set(dur, forKey: durationKey)
            self.durationDays = dur
        }
        self.savedKey = key
    }

    func clear() {
        let d = UserDefaults.standard
        d.removeObject(forKey: keyDefaultsKey)
        d.removeObject(forKey: expiresKey)
        d.removeObject(forKey: activatedKey)
        d.removeObject(forKey: durationKey)
        self.savedKey = nil
        self.expiresAt = nil
        self.activatedAt = nil
        self.durationDays = nil
    }
}
