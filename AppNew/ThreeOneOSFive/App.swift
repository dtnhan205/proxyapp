import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var supportToastModel = SupportStatusToastModel()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .vietnamese
    }

    init() {
        setupLogCapture()
        // Chạy ngay khi app mở. Mọi chỉnh sửa binary (đổi URL, hook
        // Obfuscated, rebrand bundle ID, jailbreak) → kill.
        IntegrityChecker.runStartupChecks()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Nền ảnh phủ kín toàn bộ màn hình (kể cả safe area).
                // `.scaledToFill()` giữ tỉ lệ ảnh nhưng phóng to để che hết
                // màn hình → phần ảnh thừa sẽ tràn ra ngoài. Nếu KHÔNG clip,
                // ảnh sẽ vẽ ra ngoài frame và bị SwiftUI render ra ngoài viewport
                // ("tràn sang 2 bên"). `.clipped()` cắt phần thừa ngay tại frame.
                //
                // `.frame(... infinity)` đảm bảo ảnh LUÔN được cung cấp kích
                // thước màn hình (không dựa vào intrinsic content size) — fix
                // trường hợp ảnh quá nhỏ so với màn hình iPad lớn.
                //
                // ⚠️ `.ignoresSafeArea()` áp dụng NGOÀI `.frame(...)` để:
                //   1. Background ignore safe area → fill full screen pixel
                //   2. KHÔNG lan truyền ignore-safe-area lên RootView (giữ
                //      foreground trong safe area, không gây tràn layout).
                Color.clear
                    .ignoresSafeArea()
                    .overlay {
                        ZStack(alignment: .topLeading) {
                            Image("Background")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()

                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(0.55)

                            Color.black
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(0.18)
                        }
                    }

                RootView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(supportToastModel)
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .onAppear {
                appState.detectSupport()
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?

    var isSupported: Bool { unsupportedMessage == nil }

    /// Trigger hiển thị toast thông báo support status lên top-left banner.
    /// Được gọi từ RootView ngay sau khi unlock thành công.
    func announceSupportStatus(toastModel: SupportStatusToastModel) {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        let payload = SupportStatusPayload(
            iosMajor: v.major,
            iosMinor: v.minor,
            iosPatch: v.patch,
            isSupported: supported
        )
        toastModel.present(payload)
    }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
        }
    }
}
