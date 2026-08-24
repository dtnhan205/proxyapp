import SwiftUI

struct GamePatchesView: View {
    @Environment(\.appLanguage) private var language
    let game: RemoteGameSummary
    @ObservedObject var store: PatchProjectStore

    @State private var isSyncing = false
    @State private var projectStates: [UUID: Bool] = [:]
    @State private var togglingProjectID: UUID?
    @State private var toast: ToastMessage?
    @State private var showKeySheet = false
    @State private var keyBannerVisible = true
    @State private var showPatchLog = false
    @State private var showEntryNotice: Bool = false
    @AppStorage("patch.gameEntryNoticeDismissed") private var entryNoticeDismissed: Bool = false
    @AppStorage("patch.importedOnlineIDs") private var importedOnlineIDsRaw = ""
    @AppStorage("patch.gameAssignments") private var gameAssignmentsRaw = "{}"
    @AppStorage("patch.remoteToLocalMap") private var remoteToLocalMapRaw = "{}"

    @ObservedObject private var appLog = AppLog.shared

    private var importedOnlineIDs: Set<String> {
        Set(importedOnlineIDsRaw.split(separator: ",").map(String.init))
    }

    private var gameAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(gameAssignmentsRaw.utf8))) ?? [:]
    }

    /// Server patch id -> local packageID, so a patch removed on the server can be traced back
    /// to the local file it downloaded into and deleted, instead of only ever growing the library.
    private var remoteToLocalMap: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(remoteToLocalMapRaw.utf8))) ?? [:]
    }

    private var items: [PatchLibraryItem] {
        let assignments = gameAssignments
        return store.items.filter { assignments[$0.id.uuidString] == game.id }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    menuCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .appBackground()
            .refreshable {
                await sync()
                await loadProjectStates()
            }

            // Patch log overlay
            if showPatchLog {
                patchLogOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if isSyncing {
                        HStack(spacing: 6) {
                            PulsingDot(color: AppTheme.neonCyan, size: 6)
                            NeonReadout(text: "SYNC", tint: AppTheme.neonCyan)
                        }
                    }
                    // Toggle verbose logging button
                    Button {
                        PatchLogConfig.verboseEnabled.toggle()
                        if PatchLogConfig.verboseEnabled {
                            AppLog.shared.append("[3105] Verbose logging enabled")
                        } else {
                            AppLog.shared.append("[3105] Verbose logging disabled")
                        }
                    } label: {
                        Image(systemName: PatchLogConfig.verboseEnabled ? "terminal.fill" : "terminal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PatchLogConfig.verboseEnabled ? AppTheme.neonCyan : .secondary)
                    }
                    // Show log panel button
                    Button {
                        showPatchLog.toggle()
                    } label: {
                        Image(systemName: showPatchLog ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(showPatchLog ? AppTheme.neonMagenta : .secondary)
                    }
                }
            }
        }
        .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await sync()
            await loadProjectStates()
        }
        .onAppear {
            // Vào game mà chưa nhập key thì bắt nhập ngay, không đợi Toggle.
            if !hasValidKey {
                showKeySheet = true
            }
            // Lần đầu vào game (chưa từng bấm "Không hiển thị lại") → show lưu ý
            // về Định vị + Aim. Dùng Task ngắn để alert có thời gian mount.
            if !entryNoticeDismissed {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    showEntryNotice = true
                }
            }
        }
        // Custom modal thay cho native alert — match cyberpunk theme + tách 2 bước.
        .overlay {
            if showEntryNotice {
                GameEntryNoticeModal(
                    title: language.text("patch.game_entry_notice_title"),
                    subtitle: language.text("patch.game_entry_notice_subtitle"),
                    step1Label: language.text("patch.game_entry_notice_step1_label"),
                    step1Desc: language.text("patch.game_entry_notice_step1_desc"),
                    step2Label: language.text("patch.game_entry_notice_step2_label"),
                    step2Desc: language.text("patch.game_entry_notice_step2_desc"),
                    confirmTitle: language.text("patch.game_entry_notice_confirm"),
                    dismissTitle: language.text("patch.game_entry_notice_dismiss"),
                    onConfirm: { showEntryNotice = false },
                    onDismiss: {
                        entryNoticeDismissed = true
                        showEntryNotice = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: showEntryNotice)
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
        .sheet(isPresented: $showKeySheet) {
            LicenseKeyView { _ in
                toast = ToastMessage(text: "Kích hoạt key thành công")
                // Reset visible toggles so the user sees a fresh state.
                Task { await loadProjectStates() }
            }
        }
        .toast($toast)
    }

    private var hasValidKey: Bool {
        // Nếu không có key đã lưu thì chắc chắn chưa hợp lệ. Có key rồi thì
        // mặc định coi là hợp lệ — đã qua LicenseGateView rồi (gate chỉ mở khi
        // server xác thực thành công). Không ép thêm expiresAt ở đây vì server
        // có thể không trả expiresAt cho vài response shape (vd. verify only),
        // sẽ làm giả → kẹt không bật được toggle.
        LicenseKeyManager.savedKey?.isEmpty == false
    }

    /// The single bordered box holding every patch for this game as a switch row, matching the
    /// reference "PROXY MOD MENU" card instead of a plain grouped list.
    private var menuCard: some View {
        VStack(spacing: 0) {
            menuHeader

            if items.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        itemRow(item, colorIndex: index)
                        if item.id != items.last?.id {
                            Divider()
                                .overlay(AppTheme.neonCyan.opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .techCard(glow: AppTheme.neonMagenta, opacity: 0.18)
    }

    private var menuHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppTheme.neonCyan)
                .frame(width: 3, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .shadow(color: AppTheme.neonCyan.opacity(0.8), radius: 4)
            Image(systemName: "bolt.fill")
                .font(.footnote)
                .foregroundStyle(AppTheme.neonCyan)
            Text(language.text("patch.menu_title"))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.primary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            if isSyncing {
                HStack(spacing: 6) {
                    PulsingDot(color: AppTheme.neonCyan, size: 6)
                    Text(language.text("patch.menu_auto_badge"))
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.neonCyan)
                }
            } else {
                Text(language.text("patch.menu_auto_badge"))
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.neonCyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.14), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var header: some View {
        VStack(spacing: 8) {
            gameIconView
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [AppTheme.neonCyan.opacity(0.7), AppTheme.neonMagenta.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 14, y: 6)

            Text(game.name)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            if !game.bundleID.isEmpty {
                Text(game.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var gameIconView: some View {
        if let url = game.iconURL {
            CachedAsyncImage(url: url) {
                gameIconPlaceholder
            }
        } else {
            gameIconPlaceholder
        }
    }

    private var gameIconPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: game.bannerColor) ?? AppTheme.neonCyan,
                    AppTheme.neonMagenta.opacity(0.5),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .padding(20)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                toggleRow(item, colorIndex: colorIndex)
            }
            .buttonStyle(.plain)
        } else {
            toggleRow(item, colorIndex: colorIndex)
        }
    }

    private func toggleRow(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        let rules = item.project?.rules ?? []
        let toggleableCount = rules.filter(\.canToggle).count
        let rowColor = AppTheme.rowColor(colorIndex)

        return HStack(spacing: 12) {
            Image(systemName: PatchIconCatalog.symbol(for: item.id))
                .font(.title3)
                .foregroundStyle(rowColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [rowColor.opacity(0.25), rowColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(rowColor.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: rowColor.opacity(0.35), radius: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                NeonShimmerBar(count: rules.count, tint: rowColor)
                    .padding(.top, 2)
            }
            Spacer()
            if togglingProjectID == item.id {
                ProgressView()
                    .tint(rowColor)
            } else {
                Toggle("", isOn: projectToggleBinding(for: item))
                    .labelsHidden()
                    .neonToggleTint(rowColor)
                    .disabled(!hasValidKey || toggleableCount == 0)
            }
        }
        .padding(.vertical, 10)
        .opacity(hasValidKey ? 1.0 : 0.5)
    }

    private func projectToggleBinding(for item: PatchLibraryItem) -> Binding<Bool> {
        Binding(
            get: { projectStates[item.id] ?? false },
            set: { setProjectState($0, item: item) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if isSyncing {
                ProgressView()
                    .tint(AppTheme.neonCyan)
            } else {
                Image(systemName: "shippingbox")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(AppTheme.neonCyan)
                    .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 8)
                Text(language.text("patch.empty_title"))
                    .font(.headline)
                Text(language.text("patch.game_empty_message"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    /// Downloads only this game's patches from the hub straight into the local library, so
    /// they show up here without any manual tap. Also removes local copies whose server entry
    /// disappeared (deleted on the web, or reassigned to a different game) — a pull-to-refresh
    /// should mirror the server exactly, not just ever grow. The gameId <-> local packageID and
    /// serverID <-> local packageID mappings are recorded locally since the encrypted .3105
    /// format itself carries no game association.
    private func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let remoteItems = try? await PatchHubService.fetchPatches() else { return }
        let remoteForGame = remoteItems.filter { $0.gameId == game.id }
        let remoteIDsForGame = Set(remoteForGame.map(\.id))

        var imported = importedOnlineIDs
        var assignments = gameAssignments
        var remoteMap = remoteToLocalMap
        var didChange = false

        for (serverID, localID) in remoteMap where assignments[localID] == game.id && !remoteIDsForGame.contains(serverID) {
            if let localUUID = UUID(uuidString: localID),
               let staleItem = store.items.first(where: { $0.id == localUUID }) {
                store.delete(staleItem)
            }
            assignments.removeValue(forKey: localID)
            remoteMap.removeValue(forKey: serverID)
            imported.remove(serverID)
            didChange = true
        }

        let pending = remoteForGame.filter { !imported.contains($0.id) }
        for item in pending {
            do {
                let fileURL = try await PatchHubService.downloadPatch(item)
                let packageIDString: String? = await Task.detached(priority: .utility) {
                    do {
                        let data = try PatchProjectLibrary.readPackage(at: fileURL)
                        let summary = try PatchPackageCodec.inspect(data)
                        _ = try PatchProjectLibrary.save(data: data, projectName: item.name)
                        try? FileManager.default.removeItem(at: fileURL)
                        return summary.packageID.uuidString
                    } catch {
                        return nil
                    }
                }.value
                if let packageIDString {
                    imported.insert(item.id)
                    assignments[packageIDString] = game.id
                    remoteMap[item.id] = packageIDString
                    didChange = true
                }
            } catch {
                continue
            }
        }

        importedOnlineIDsRaw = imported.joined(separator: ",")
        if let encoded = try? JSONEncoder().encode(assignments), let json = String(data: encoded, encoding: .utf8) {
            gameAssignmentsRaw = json
        }
        if let encoded = try? JSONEncoder().encode(remoteMap), let json = String(data: encoded, encoding: .utf8) {
            remoteToLocalMapRaw = json
        }
        if didChange {
            store.reload()
        }
    }

    /// A patch's toggle reflects every toggle-capable rule in it at once: on only when all of
    /// them currently show their replacement active on disk, off otherwise (including "never
    /// applied yet"). Rules without a bundled original are skipped — they simply can't report
    /// or accept an "off" state.
    private func loadProjectStates() async {
        let currentItems = items
        guard !currentItems.isEmpty else { return }
        let states: [UUID: Bool] = await Task.detached(priority: .userInitiated) {
            var result: [UUID: Bool] = [:]
            for item in currentItems {
                let toggleableRules = (item.project?.rules ?? []).filter(\.canToggle)
                guard !toggleableRules.isEmpty else { continue }
                let allOn = toggleableRules.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
                result[item.id] = allOn
            }
            return result
        }.value
        projectStates = states
    }

    private func setProjectState(_ isOn: Bool, item: PatchLibraryItem) {
        let toggleableRules = (item.project?.rules ?? []).filter(\.canToggle)
        guard !toggleableRules.isEmpty, togglingProjectID == nil else { return }

        // License gate: every toggle verifies the saved key with the server
        // before touching the filesystem. A revoked / expired / missing key
        // short-circuits and surfaces the activation sheet for the user.
        guard hasValidKey else {
            toast = ToastMessage(text: "Vui lòng nhập key để sử dụng")
            showKeySheet = true
            return
        }

        togglingProjectID = item.id
        Task.detached(priority: .userInitiated) {
            // Server-side verification first — admin can revoke the key in
            // real time and the next toggle will be blocked accordingly.
            do {
                _ = try await LicenseKeyManager.verifySavedKey()
            } catch let err as LicenseKeyError {
                let msg = err.errorDescription ?? "Key không hợp lệ"
                await MainActor.run {
                    togglingProjectID = nil
                    toast = ToastMessage(text: "Vui lòng nhập key để sử dụng")
                    showKeySheet = true
                }
                AppLog.shared.append("[license] verify failed before toggle: \(msg)")
                return
            } catch {
                await MainActor.run {
                    togglingProjectID = nil
                    toast = ToastMessage(text: "Lỗi xác thực key. Vui lòng thử lại")
                }
                return
            }

            var failure: PatchPackageError?
            for rule in toggleableRules {
                do {
                    try DevicePatchService.setRuleState(isOn, rule: rule)
                } catch let error as PatchPackageError {
                    failure = error
                } catch {
                    failure = .applyFailed
                }
            }
            // Re-read actual on-device state rather than assume success, since a partial
            // failure partway through the loop would otherwise show a state that never
            // really landed on every file.
            let actualState = toggleableRules.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
            // Capture `failure` into a local before hopping to the main actor, so the
            // closure doesn't reference the mutable `var` from the detached task context
            // (which would warn under Swift 6 concurrency rules).
            let capturedFailure = failure
            await MainActor.run {
                togglingProjectID = nil
                projectStates[item.id] = actualState
                if let capturedFailure {
                    store.alert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: capturedFailure.localizationKey,
                        messageArgument: capturedFailure.localizationArgument
                    )
                } else if actualState == isOn {
                    let name = item.project?.name ?? language.text("patch.locked_project")
                    let key = isOn ? "patch.toggle_on_success" : "patch.toggle_off_success"
                    toast = ToastMessage(text: language.text(key, name))
                }
                // Show log on failure
                if capturedFailure != nil {
                    showPatchLog = true
                }
            }
        }
    }

    // MARK: - Patch Log Overlay

    private var patchLogOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PATCH LOG")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.neonCyan)
                Spacer()
                Button {
                    var text = ""
                    text += "3105 Log\n"
                    text += "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))\n"
                    text += "Generated: \(Date())\n\n"
                    text += appLog.entries.joined(separator: "\n")
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.neonCyan)
                }
                Button {
                    appLog.entries.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Button {
                    showPatchLog = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.9))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(appLog.entries.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color.black.opacity(0.95))
                .onChange(of: appLog.entries.count) { count in
                    if count > 0 {
                        withAnimation {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppTheme.neonMagenta.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: AppTheme.neonMagenta.opacity(0.3), radius: 10)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Game Entry Notice Modal

/// Modal "Trước khi vào game" hiển thị khi user mở 1 game lần đầu.
/// Thay thế native `.alert` để match cyberpunk theme + tách rõ 2 bước
/// (Định vị → Aim) bằng icon + màu riêng.
private struct GameEntryNoticeModal: View {
    let title: String
    let subtitle: String
    let step1Label: String
    let step1Desc: String
    let step2Label: String
    let step2Desc: String
    let confirmTitle: String
    let dismissTitle: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Backdrop mờ — không dùng .ultraThinMaterial để tránh GPU cost
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // Card chính
            VStack(spacing: 0) {
                header
                Divider()
                    .overlay(AppTheme.neonCyan.opacity(0.18))
                stepsSection
                Divider()
                    .overlay(AppTheme.neonCyan.opacity(0.18))
                footer
            }
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: AppTheme.neonCyan.opacity(0.35), radius: 24, y: 0)
            .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
            .padding(.horizontal, 22)
        }
        .onTapGesture { /* nuốt tap để không lan ra ngoài */ }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                // Vòng glow phía sau icon — static, không animation
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.neonCyan.opacity(0.35),
                                AppTheme.neonCyan.opacity(0.0),
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 36
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.neonCyan)
                    .shadow(color: AppTheme.neonCyan.opacity(0.7), radius: 6)
            }

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 22)
        .padding(.bottom, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: Steps

    private var stepsSection: some View {
        VStack(spacing: 10) {
            stepRow(
                index: 1,
                icon: "location.fill",
                iconColor: AppTheme.neonCyan,
                label: step1Label,
                desc: step1Desc
            )
            stepRow(
                index: 2,
                icon: "scope",
                iconColor: AppTheme.neonMagenta,
                label: step2Label,
                desc: step2Desc
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func stepRow(
        index: Int,
        icon: String,
        iconColor: Color,
        label: String,
        desc: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon chip với số thứ tự nhỏ ở góc
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(iconColor.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)
                    .shadow(color: iconColor.opacity(0.55), radius: 4)

                Text("\(index)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(iconColor, in: Capsule())
                    .offset(x: 6, y: -4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Button(action: onConfirm) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                    Text(confirmTitle)
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AppTheme.neonCyan, AppTheme.neonIce],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: AppTheme.neonCyan.opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Text(dismissTitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: Card background & border

    private var cardBackground: some View {
        ZStack {
            // Base dark fill
            Color(red: 0.06, green: 0.09, blue: 0.14)
            // Subtle top-down gradient cho chiều sâu
            LinearGradient(
                colors: [
                    AppTheme.neonCyan.opacity(0.10),
                    .clear,
                    AppTheme.neonMagenta.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        AppTheme.neonCyan.opacity(0.7),
                        AppTheme.neonCyan.opacity(0.25),
                        AppTheme.neonMagenta.opacity(0.55),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
    }
}
