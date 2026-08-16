import SwiftUI

/// Root view — quyết định hiện LicenseGateView hay ContentView.
/// - Khi chưa có key → gate.
/// - Khi đã có key local → verify lại server trước khi cho vào.
/// - Khi server từ chối (revoked/expired/wrong-device) → quay về gate.
struct RootView: View {

    @StateObject private var store = LicenseStore.shared
    @State private var gateDecision: GateDecision = .checking

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
        }
        .task { await evaluate() }
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
                // Verify OK → RAM chưa có expiresAt vì init() không đọc cache.
                // Khôi phục từ UserDefaults để footer đếm ngược thời gian còn lại
                // thực của key, không reset về 0.
                store.restoreSession()
                gateDecision = .unlocked
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
