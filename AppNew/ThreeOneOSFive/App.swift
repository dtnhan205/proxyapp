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
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Lớp phủ mờ để chữ trên ảnh nền luôn đọc được.
                // `.ultraThinMaterial` của SwiftUI blur ảnh nhẹ + darken
                // → text/icon cyan/magenta vẫn pop trên nền ảnh.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .opacity(0.55)

                // Fallback tối nếu asset "Background" không load được
                // (ví dụ Xcode cache cũ) — gradient nền đảm bảo không bị
                // nền trắng chói.
                Color.black
                    .ignoresSafeArea()
                    .opacity(0.18)

                RootView()
            }
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
