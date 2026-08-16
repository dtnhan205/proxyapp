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
        self.savedKey = nil
        self.expiresAt = nil
        self.activatedAt = nil
        self.durationDays = nil
    }

    var isSaved: Bool { (savedKey?.isEmpty == false) }

    func save(key: String, status: RemoteKeyStatus) {
        let d = UserDefaults.standard
        d.set(key, forKey: keyDefaultsKey)
        if let s = status.expiresAt, let date = ISO8601DateFormatter().date(from: s) {
            d.set(date.timeIntervalSince1970, forKey: expiresKey)
            self.expiresAt = date
        }
        if let s = status.activatedAt, let date = ISO8601DateFormatter().date(from: s) {
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
