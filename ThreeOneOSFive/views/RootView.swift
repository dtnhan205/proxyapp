import SwiftUI

/// Root view — quyết định hiện LicenseGateView hay ContentView.
/// - Khi chưa có key → gate.
/// - Khi đã có key local → verify lại server trước khi cho vào.
/// - Khi server từ chối (revoked/expired/wrong-device) → quay về gate.
/// - Khi server trả build_revoked/build_unknown → phủ overlay full-screen,
///   block toàn bộ tương tác, persist qua UserDefaults.
struct RootView: View {

    @StateObject private var store = LicenseStore.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var supportToastModel: SupportStatusToastModel
    @State private var gateDecision: GateDecision = .checking
    @State private var didAnnounceSupport: Bool = false

    enum GateDecision {
        case checking
        case unlocked
        case needsKey
    }

    var body: some View {
        ZStack {
            switch gateDecision {
            case .unlocked:
                ContentView()
                    .environmentObject(store)
                    .transition(.opacity)
            case .needsKey, .checking:
                LicenseGateView(onUnlock: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateDecision = .unlocked
                    }
                })
                .environmentObject(store)
                .transition(.opacity)
            }

            // Build-blocked overlay phủ full-screen, đặt SAU các view
            // chính nên nó nằm trên cùng. Vì ZStack overlay theo thứ tự
            // declaration, đặt cuối = trên cùng. `.allowsHitTesting(true)`
            // chặn mọi tap xuống các view bên dưới.
            if store.buildBlocked {
                BuildBlockedOverlay()
                    .transition(.opacity)
                    .zIndex(.greatestFiniteMagnitude)
            }
        }
        .task { await evaluate() }
        .onChange(of: gateDecision) { newValue in
            // Toast chỉ trigger DUY NHẤT một lần khi vừa unlock thành công.
            // Nếu user bị buildRevoked → quay lại gate → reset flag để lần
            // unlock sau (nếu có) vẫn toast.
            switch newValue {
            case .unlocked:
                if !didAnnounceSupport {
                    didAnnounceSupport = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        appState.announceSupportStatus(toastModel: supportToastModel)
                    }
                }
            case .needsKey:
                // Reset để lần unlock kế tiếp lại toast.
                didAnnounceSupport = false
            case .checking:
                break
            }
        }
    }

    private func evaluate() async {
        guard let key = store.savedKey, !key.isEmpty else {
            await MainActor.run { gateDecision = .needsKey }
            return
        }
        do {
            let serial = DeviceIdentity.serial()
            _ = try await PatchHubService.verifyKey(key: key, deviceSerial: serial)
            await MainActor.run {
                // Verify OK → build token hợp lệ. Clear block flag nếu có
                // (phòng khi user build cũ đã bị block, build mới add token
                // mới → sau khi verify thành công sẽ tự gỡ overlay).
                store.setBuildBlocked(false)
                // Verify OK → RAM chưa có expiresAt vì init() không đọc cache.
                // Khôi phục từ UserDefaults để footer đếm ngược thời gian còn lại
                // thực của key, không reset về 0.
                store.restoreSession()
                gateDecision = .unlocked
            }
        } catch let error as LicenseKeyError {
            // Build bị revoke / unknown → bật overlay và KHÔNG clear key.
            // User vẫn thấy overlay kể cả khi restart app.
            switch error {
            case .buildRevoked, .buildUnknown, .buildMissing:
                await MainActor.run {
                    store.setBuildBlocked(true)
                    gateDecision = .needsKey
                }
                return
            default:
                break
            }
            // Verify fail (key bình thường) — xoá key local, đẩy về gate.
            await MainActor.run {
                store.clear()
                gateDecision = .needsKey
            }
        } catch {
            // Verify fail — xoá key local, đẩy về gate.
            await MainActor.run {
                store.clear()
                gateDecision = .needsKey
            }
        }
    }
}
