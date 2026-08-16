import Foundation

/// Lưu key + thông tin phiên đăng nhập vào UserDefaults. Chỉ lưu local — việc
/// xác thực thật sự vẫn phải qua server mỗi lần mở app.
final class LicenseStore: ObservableObject {

    static let shared = LicenseStore()

    @Published private(set) var savedKey: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var activatedAt: Date?
    @Published private(set) var durationDays: Int?
    /// Khi `true` → overlay "Đã có phiên bản mới..." phủ full-screen và
    /// block toàn bộ tương tác. Persist qua UserDefaults nên thoát ra vào
    /// lại vẫn thấy. Chỉ xoá khi verify/activate thành công trở lại.
    @Published private(set) var buildBlocked: Bool = false

    private let keyDefaultsKey = "license.savedKey"
    private let expiresKey = "license.expiresAt"
    private let activatedKey = "license.activatedAt"
    private let durationKey = "license.durationDays"
    private let buildBlockedKey = "license.buildBlocked"

    private init() {
        // Mỗi lần vào app đều bắt nhập lại: không đọc key từ UserDefaults khi
        // khởi động. Key hợp lệ chỉ tồn tại trong RAM trong phiên hiện tại; bản
        // lưu trên UserDefaults (nếu có) chỉ dùng để Logout/clear().
        // Riêng thời gian (expiresAt) đọc từ cache để footer vẫn đếm ngược chuẩn
        // thời gian còn lại thực của key, không bị reset khi user nhập lại key.
        self.savedKey = nil
        self.activatedAt = nil
        self.durationDays = nil
        self.buildBlocked = UserDefaults.standard.bool(forKey: buildBlockedKey)
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
        if let s = status.expiresAt, let date = Self.parseISO8601(s) {
            resolvedExpiresAt = date
        }
        var resolvedActivatedAt: Date?
        if let s = status.activatedAt, let date = Self.parseISO8601(s) {
            resolvedActivatedAt = date
        }
        // Fallback khi server không trả expiresAt: nếu có durationDays thì tính
        // từ thời điểm hiện tại hoặc từ activatedAt tuỳ ngữ cảnh.
        // - `firstActivation == true` hoặc server không trả trường này: ưu tiên
        //   dùng `Date()` để user thấy đúng tổng `durationDays` còn lại (UX
        //   cho first-time bind và cho legacy server không trả firstActivation).
        // - `firstActivation == false` (re-bind device): dùng activatedAt server
        //   gửi để phản ánh đúng thời gian còn lại thực của key.
        if resolvedExpiresAt == nil, let dur = status.durationDays, dur > 0 {
            if status.firstActivation == false, let base = resolvedActivatedAt {
                resolvedExpiresAt = base.addingTimeInterval(TimeInterval(dur) * 86_400)
            } else {
                resolvedExpiresAt = Date().addingTimeInterval(TimeInterval(dur) * 86_400)
            }
        }
        NSLog("[LicenseStore] save key=\(key) expiresAtString=\(status.expiresAt ?? "<nil>") activatedAtString=\(status.activatedAt ?? "<nil>") durationDays=\(status.durationDays ?? -1) resolvedExpiresAt=\(resolvedExpiresAt?.description ?? "<nil>") now=\(Date().description)")
        if let exp = resolvedExpiresAt {
            let secs = Int(exp.timeIntervalSinceNow)
            NSLog("[LicenseStore] countdown remaining=\(secs)s (\(secs/3600)h\( (secs%3600)/60 )m\(secs%60)s) expLocal=\(exp.description)")
        }
        // Ưu tiên server response làm mốc duy nhất. Local cache chỉ dùng ở
        // `init()` để hiển thị countdown trong lúc chờ auth — không được override
        // response mới từ server, vì server nắm quyền quyết định thời hạn thực.
        let finalExpiresAt: Date? = resolvedExpiresAt
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

    /// Persist cờ build-blocked lên UserDefaults. Khi server trả
    /// `build_revoked` / `build_unknown` → gọi hàm này với `true` → overlay
    /// sẽ phủ full-screen ngay khi RootView render.
    func setBuildBlocked(_ blocked: Bool) {
        UserDefaults.standard.set(blocked, forKey: buildBlockedKey)
        self.buildBlocked = blocked
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

    /// Parse ISO8601 — chấp nhận cả `Z` và `+07:00`; thử cả có/không fractional
    /// seconds. Trả về UTC an toàn để cộng `durationDays` không lệch.
    private static func parseISO8601(_ s: String) -> Date? {
        let withInternet = ISO8601DateFormatter()
        withInternet.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withInternet.date(from: s) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: s) { return date }
        return nil
    }
}
