import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Cá»­a sá»• hiá»ƒn thá»‹ tráº¡ng thÃ¡i vÃ  hÆ°á»›ng dáº«n GhÃ©p ÄÃ´i iOS 27 (RemotePairing)
/// TÆ°Æ¡ng thÃ­ch hoÃ n toÃ n vá»›i cÆ¡ cháº¿ ghÃ©p Ä‘Ã´i khÃ´ng dÃ¢y (Developer Mode) vÃ  AirTraffic/LocalDevVPN cá»§a iOS 27+.
struct RemotePairingSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var pairing = RemotePairingAdvertiser.shared
    @ObservedObject private var vpnManager = LocalDevVPNManager.shared
    @AppStorage(AppLanguage.storageKey) private var languageCode: String = AppLanguage.vietnamese.rawValue

    @State private var isPulsing: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showClearAlert: Bool = false
    @State private var diagnosticLogs: [String] = []
    @State private var isRunningProbe: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var isTestingInject: Bool = false
    @State private var showTestInjectAlert: Bool = false
    @State private var testInjectAlertText: String = ""
    @State private var showShareSheet: Bool = false

    private var isEnglish: Bool {
        languageCode == AppLanguage.english.rawValue
    }

    var body: some View {
        ZStack {
            // Ná»n tá»‘i Cyberpunk sang trá»ng
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Hiá»‡u á»©ng Ã¡nh sÃ¡ng ná»n
            VStack {
                Circle()
                    .fill(AppTheme.neonCyan.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(y: -120)
                Spacer()
            }

            VStack(spacing: 0) {
                // Header Bar
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Banner ThÃ nh cÃ´ng náº¿u ÄÃƒ CÃ“ FILE PAIRING
                        if pairing.hasExistingPairing {
                            pairedSuccessBanner
                        }

                        // Cáº£nh bÃ¡o Wi-Fi náº¿u CHÆ¯A GHÃ‰P ÄÃ”I vÃ  Ä‘ang dÃ¹ng 4G
                        if !pairing.hasExistingPairing && !pairing.isWiFiConnected {
                            wifiWarningCard
                        }

                        // Card Tráº¡ng thÃ¡i phÃ¡t sÃ³ng Bonjour / Conduit
                        broadcastingCard

                        // Card HÃ nh Ä‘á»™ng ghÃ©p Ä‘Ã´i (Nháº­p file .plist)
                        quickActionsCard

                        // Card Nháº­t kÃ½ phÃ¡t tÃ­n hiá»‡u ghÃ©p Ä‘Ã´i Bonjour (Realtime)
                        // livePairingLogsCard

                        // Card Nháº­t kÃ½ kiá»ƒm tra thá»±c táº¿ File Pairing & Documents Free Fire
                        // diagnosticConsoleCard

                        // Card MÃ£ PIN (náº¿u cÃ³ yÃªu cáº§u tá»« há»‡ thá»‘ng)
                        if !pairing.pinCode.isEmpty {
                            pinCodeCard
                        }

                        // Card CÃ¡c bÆ°á»›c thá»±c hiá»‡n chi tiáº¿t
                        pairingStepsCard

                        // Card ThÃ´ng sá»‘ ká»¹ thuáº­t
                        techDetailsCard

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }

                // Bottom Action Buttons
                bottomActionBar
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.95))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1),
                        alignment: .top
                    )
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "plist") ?? .data,
                UTType(filenameExtension: "mobiledevicepairing") ?? .data,
                UTType(filenameExtension: "mobilepair") ?? .data,
                .data
            ]
        ) { result in
            switch result {
            case .success(let url):
                if pairing.importPairingFile(from: url) {
                    runProbe()
                }
            case .failure(let error):
                print("[RemotePairing] File picker error: \(error)")
            }
        }
        .alert(
            isEnglish ? "Delete pairing record?" : "XÃ¡c nháº­n xoÃ¡ file Pairing?",
            isPresented: $showClearAlert
        ) {
            Button(isEnglish ? "Delete" : "XoÃ¡", role: .destructive) {
                pairing.clearPairing()
                runProbe()
            }
            Button(isEnglish ? "Cancel" : "Huá»·", role: .cancel) {}
        } message: {
            Text(isEnglish
                ? "This will delete the pairing credentials from the device."
                : "HÃ nh Ä‘á»™ng nÃ y sáº½ xoÃ¡ file pairing hiá»‡n táº¡i Ä‘á»ƒ báº¡n cÃ³ thá»ƒ táº¡o má»›i hoáº·c nháº­p file khÃ¡c.")
        }
        .alert(
            isEnglish ? "Copied to Clipboard" : "ÄÃ£ sao chÃ©p nháº­t kÃ½",
            isPresented: $showCopiedAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isEnglish ? "Diagnostic logs copied successfully." : "ToÃ n bá»™ nháº­t kÃ½ kiá»ƒm tra Ä‘Ã£ Ä‘Æ°á»£c sao chÃ©p vÃ o bá»™ nhá»› táº¡m.")
        }
        .alert(
            isEnglish ? "Inject Test Result" : "Káº¿t Quáº£ Kiá»ƒm Tra Inject",
            isPresented: $showTestInjectAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(testInjectAlertText)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [AppLog.shared.exportLogURL()])
        }
        .onAppear {
            isPulsing = true
            if !pairing.isAdvertising {
                pairing.startAdvertising()
            }
            runProbe()
        }
    }

    // MARK: - Run Diagnostics Probe
    private func runProbe() {
        isRunningProbe = true
        DispatchQueue.global(qos: .userInitiated).async {
            let logs = LocalDevVPNBridge.runFullDiagnostics()
            DispatchQueue.main.async {
                self.diagnosticLogs = logs
                self.isRunningProbe = false
            }
        }
    }

    // MARK: - Test Inject Cheat Directly
    private func runInjectTest() {
        guard !isTestingInject else { return }
        isTestingInject = true

        let target = FreeFirePatchService.selectedTarget
        diagnosticLogs.append("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
        diagnosticLogs.append("[TEST] ðŸš€ Báº®T Äáº¦U KIá»‚M TRA INJECT VÃ€O \(target.displayName.uppercased())...")
        diagnosticLogs.append("[TEST] ðŸ“ File Pairing: \(pairing.pairingFilePath) (\(pairing.hasExistingPairing ? "OK" : "CHÆ¯A CÃ“"))")
        let vpn = LocalDevVPNBridge.detectVPNInterface()
        diagnosticLogs.append("[TEST] ðŸŒ LocalDevVPN: \(vpn.active ? "Äang Báº¬T (\(vpn.deviceIP))" : "Äang Táº®T (NÃªn báº­t Ä‘á»ƒ má»Ÿ cá»•ng RSD 49152)")")
        diagnosticLogs.append("[TEST] ðŸ“¶ Wi-Fi IP: \(RemotePairingAdvertiser.getWiFiAddress() ?? "KhÃ´ng cÃ³")")

        Task {
            do {
                try await FreeFirePatchService.inject(target: target)
                await MainActor.run {
                    self.isTestingInject = false
                    self.diagnosticLogs.append("[TEST] ðŸŽ‰ Káº¾T QUáº¢: INJECT THÃ€NH CÃ”NG 100% VÃ€O GAME!")
                    self.diagnosticLogs.append("[TEST] ðŸ’¡ Báº¡n cÃ³ thá»ƒ má»Ÿ \(target.displayName) Ä‘á»ƒ tráº£i nghiá»‡m.")
                    self.testInjectAlertText = "ðŸŽ‰ INJECT THÃ€NH CÃ”NG!\nÄÃ£ náº¡p toÃ n bá»™ module cheat vÃ o \(target.displayName) qua káº¿t ná»‘i Developer Mode!"
                    self.showTestInjectAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isTestingInject = false
                    self.diagnosticLogs.append("[TEST] âŒ Lá»–I INJECT: \(error.localizedDescription)")
                    self.testInjectAlertText = "âŒ Lá»–I INJECT:\n\(error.localizedDescription)\n\nðŸ‘‰ Vui lÃ²ng xem chi tiáº¿t trong khung 'NHáº¬T KÃ KIá»‚M TRA TRUY Cáº¬P THá»°C Táº¾' bÃªn dÆ°á»›i!"
                    self.showTestInjectAlert = true
                }
            }
        }
    }

    // MARK: - Live Pairing Broadcast Logs Card
    private var livePairingLogsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(AppTheme.neonLime)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(isEnglish ? "LIVE BONJOUR & BROADCAST LOGS" : "NHáº¬T KÃ PHÃT TÃN HIá»†U GHÃ‰P ÄÃ”I (REALTIME)")
                        .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonLime)
                    Text(isEnglish ? "Verifies mDNS broadcast, port binding, and handshake" : "Chi tiáº¿t socket, cá»•ng káº¿t ná»‘i, phÃ¡t mDNS vÃ  báº¯t tay há»‡ thá»‘ng")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(pairing.isPublishedSuccessfully ? AppTheme.neonLime : (pairing.isAdvertising ? AppTheme.neonAmber : Color.gray))
                        .frame(width: 6, height: 6)
                    Text(pairing.isPublishedSuccessfully ? "mDNS: OK" : (pairing.isAdvertising ? "WAITING" : "OFF"))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(pairing.isPublishedSuccessfully ? AppTheme.neonLime : (pairing.isAdvertising ? AppTheme.neonAmber : .gray))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }

            // Terminal View
            VStack(alignment: .leading, spacing: 4) {
                if pairing.logs.isEmpty {
                    Text(isEnglish ? "No broadcast logs yet. Tap Start to begin broadcasting." : "ChÆ°a cÃ³ log phÃ¡t sÃ³ng. Dá»‹ch vá»¥ Ä‘ang sáºµn sÃ ng.")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(pairing.logs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(colorForLogLine(line))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.neonLime.opacity(0.25), lineWidth: 1)
            )

            // Footer bar
            HStack {
                Button {
                    UIPasteboard.general.string = pairing.logs.joined(separator: "\n")
                    showCopiedAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Copy Logs" : "Sao chÃ©p")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    AppLog.shared.flush()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Export log.txt" : "Xuáº¥t log.txt")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.neonLime)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonLime.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(pairing.isWiFiConnected
                    ? "ðŸ“¶ Wi-Fi: \(RemotePairingAdvertiser.getWiFiAddress() ?? "OK")"
                    : "âš ï¸ KHÃ”NG CÃ“ WI-FI (4G)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(pairing.isWiFiConnected ? AppTheme.neonCyan : AppTheme.neonAmber)
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonLime.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Diagnostic Console Card (Log thá»±c táº¿ kiá»ƒm tra Pairing & Documents)
    private var diagnosticConsoleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(AppTheme.neonCyan)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(isEnglish ? "FILE & DOCUMENTS ACCESS LOGS" : "NHáº¬T KÃ KIá»‚M TRA TRUY Cáº¬P THá»°C Táº¾")
                        .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                    Text(isEnglish ? "Verifies pairing record & Free Fire container access" : "XÃ¡c thá»±c file pairing vÃ  quyá»n truy cáº­p Documents cá»§a game")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Button {
                    runProbe()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isRunningProbe ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .rotationEffect(isRunningProbe ? .degrees(360) : .zero)
                            .animation(isRunningProbe ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRunningProbe)
                        Text(isEnglish ? "Re-test" : "QuÃ©t láº¡i")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.neonCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRunningProbe)
            }

            // Terminal View
            VStack(alignment: .leading, spacing: 4) {
                if diagnosticLogs.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                            .scaleEffect(0.7)
                        Text(isEnglish ? "Running diagnostics probe..." : "Äang cháº¡y kiá»ƒm tra truy cáº­p...")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(diagnosticLogs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(colorForLogLine(line))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.neonCyan.opacity(0.25), lineWidth: 1)
            )

            // Footer bar: Sao chÃ©p nháº­t kÃ½ & Giáº£i thÃ­ch káº¿t quáº£
            HStack {
                Button {
                    UIPasteboard.general.string = diagnosticLogs.joined(separator: "\n")
                    showCopiedAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Copy Logs" : "Sao chÃ©p")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    AppLog.shared.flush()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Export log.txt" : "Xuáº¥t log.txt")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.neonCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(diagnosticLogs.contains(where: { $0.contains("100% ACCESS") || $0.contains("ÄÃƒ GHI & Äá»ŒC THÃ€NH CÃ”NG") })
                    ? (isEnglish ? "âœ… DOCUMENTS ACCESS: VERIFIED" : "âœ… QUYá»€N TRUY Cáº¬P DOCUMENTS: OK")
                    : (isEnglish ? "âš ï¸ PENDING GAME LAUNCH" : "âš ï¸ Cáº¦N Má»ž GAME 1 Láº¦N"))
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(diagnosticLogs.contains(where: { $0.contains("100% ACCESS") || $0.contains("ÄÃƒ GHI & Äá»ŒC THÃ€NH CÃ”NG") }) ? AppTheme.neonLime : AppTheme.neonAmber)
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
        )
    }

    private func colorForLogLine(_ line: String) -> Color {
        if line.contains("âœ…") || line.contains("100% ACCESS") || line.contains("THÃ€NH CÃ”NG") {
            return AppTheme.neonLime
        } else if line.contains("âŒ") || line.contains("Lá»—i") || line.contains("FAILED") {
            return AppTheme.neonRed
        } else if line.contains("âš ï¸") || line.contains("CHÆ¯A CÃ“") || line.contains("ÄANG Táº®T") {
            return AppTheme.neonAmber
        } else if line.contains("ðŸŽ®") || line.contains("ðŸš€") || line.contains("ðŸ") {
            return AppTheme.neonCyan
        } else if line.contains("ðŸ“‚") || line.contains("ðŸ“") || line.contains("ðŸ“„") {
            return Color(red: 0.6, green: 0.85, blue: 1.0)
        } else {
            return Color.white.opacity(0.85)
        }
    }

    // MARK: - Paired Success Banner
    private var pairedSuccessBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.neonLime.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.neonLime)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isEnglish ? "PAIRING ACTIVE (READY)" : "GHÃ‰P ÄÃ”I THÃ€NH CÃ”NG (ÄÃƒ Sáº´N SÃ€NG)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonLime)

                    Text(isEnglish ? "Valid Pairing Record found on device" : "ÄÃ£ cÃ³ File Pairing há»£p lá»‡ trÃªn mÃ¡y")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }

            Text(isEnglish
                ? "Pairing record verified on-device! You DO NOT need to pair in Settings Developer Mode. Simply turn ON LocalDevVPN, open Free Fire, and apply mods directly!"
                : "ÄÃ£ cÃ³ File Pairing há»£p lá»‡ trÃªn mÃ¡y! Báº¡n KHÃ”NG Cáº¦N pháº£i vÃ o CÃ i Ä‘áº·t Cháº¿ Ä‘á»™ NhÃ  phÃ¡t triá»ƒn Ä‘á»ƒ ghÃ©p Ä‘Ã´i ná»¯a. Chá»‰ cáº§n: Báº­t LocalDevVPN -> Má»Ÿ game Free Fire -> Báº¥m Náº¡p Mod lÃ  hoÃ n táº¥t 100%!")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2.5)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.neonLime)
                    .font(.system(size: 11))
                Text(isEnglish ? "Pairing active. Turn on LocalDevVPN and open game!" : "GhÃ©p Ä‘Ã´i sáºµn sÃ ng. HÃ£y Báº­t LocalDevVPN vÃ  má»Ÿ game náº¡p mod ngay!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.neonLime)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(red: 0.05, green: 0.16, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonLime.opacity(0.8), lineWidth: 1.5)
        )
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pairing.hasExistingPairing ? AppTheme.neonLime : (pairing.isAdvertising ? AppTheme.neonCyan : AppTheme.neonAmber))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)

                    Text(isEnglish ? "iOS 27 PAIRING CONDUIT" : "GHÃ‰P ÄÃ”I iOS 27")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                }

                Text(isEnglish ? "Developer Mode Wireless Pairing" : "GhÃ©p Ä‘Ã´i Cháº¿ Ä‘á»™ NhÃ  phÃ¡t triá»ƒn")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Broadcasting Card
    private var broadcastingCard: some View {
        VStack(spacing: 12) {
            radarAnimationView
            broadcastingInfoSection
            broadcastingPillsSection
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    (pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.45),
                    lineWidth: 1
                )
        )
    }

    private var radarAnimationView: some View {
        ZStack {
            radarRingsView

            Circle()
                .fill(
                    LinearGradient(
                        colors: pairing.hasExistingPairing
                            ? [AppTheme.neonLime, Color(red: 0.1, green: 0.8, blue: 0.3)]
                            : [AppTheme.neonCyan, Color(red: 0.0, green: 0.48, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .shadow(color: (pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.6), radius: 10)

            Image(systemName: pairing.hasExistingPairing ? "checkmark.seal.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.top, 10)
    }

    private var radarRingsView: some View {
        ZStack {
            Circle()
                .strokeBorder((pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.25), lineWidth: 1.5)
                .frame(width: 64, height: 64)

            Circle()
                .strokeBorder((pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.18), lineWidth: 1.5)
                .frame(width: 92, height: 92)

            Circle()
                .strokeBorder((pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.11), lineWidth: 1.5)
                .frame(width: 120, height: 120)
        }
        .scaleEffect(isPulsing ? 1.08 : 0.95)
        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
    }

    private var broadcastingInfoSection: some View {
        VStack(spacing: 4) {
            Text(pairing.advertisedName)
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)

            Text(pairing.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonAmber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private var broadcastingPillsSection: some View {
        HStack(spacing: 8) {
            statusPill(
                icon: "network",
                label: "PORT",
                value: "\(pairing.listeningPort)"
            )
            statusPill(
                icon: pairing.isWiFiConnected ? "wifi" : "wifi.slash",
                label: "NETWORK",
                value: pairing.isWiFiConnected ? "WI-FI OK" : "4G (CELLULAR)"
            )
            statusPill(
                icon: "lock.shield.fill",
                label: "STATUS",
                value: pairing.hasExistingPairing ? "PAIRED" : "READY"
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        VStack(spacing: 10) {
            // NÃºt Má»Ÿ á»¨ng Dá»¥ng LocalDevVPN (náº¿u VPN chÆ°a báº­t)
            if !vpnManager.isConnected {
                Button {
                    if let url = URL(string: "localdevvpn://"), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        diagnosticLogs.append("[VPN] â„¹ï¸ HÃ£y thoÃ¡t ra mÃ n hÃ¬nh chÃ­nh vÃ  má»Ÿ app LocalDevVPN")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 13, weight: .bold))
                        Text(isEnglish ? "OPEN LOCALDEVVPN APP" : "ðŸŒ Má»ž APP LOCALDEVVPN (KÃCH HOáº T 10.7.0.1)")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(AppTheme.neonCyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(AppTheme.neonCyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppTheme.neonCyan.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // NÃºt 2: Nháº­p file pairing (.plist) tá»« mÃ¡y tÃ­nh (pymobiledevice3 / Files)
            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(isEnglish ? "IMPORT PAIRING FILE (.plist)" : "NHáº¬P FILE PAIRING (.plist Tá»ª MÃY TÃNH)")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                }
                .foregroundColor(AppTheme.neonCyan)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.neonCyan.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // NÃºt 3 (náº¿u Ä‘Ã£ cÃ³ file): XoÃ¡ file Ä‘á»ƒ thiáº¿t láº­p láº¡i
            if pairing.hasExistingPairing {
                Button {
                    showClearAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text(isEnglish ? "Reset Pairing Record" : "XoÃ¡ file Pairing Ä‘á»ƒ táº¡o láº¡i")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.neonRed.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Wi-Fi Warning Card
    private var wifiWarningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.neonAmber)
                Text(isEnglish ? "NO WI-FI CONNECTION DETECTED" : "CHÆ¯A Káº¾T Ná»I WI-FI")
                    .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonAmber)
                Spacer()
            }

            Text(isEnglish
                ? "Bonjour scanning requires Wi-Fi. You can connect to Wi-Fi to pair in iPhone Settings, or import a pairing record (.plist) from your computer."
                : "QuÃ©t Bonjour Ä‘Ã²i há»i Wi-Fi. HÃ£y káº¿t ná»‘i Wi-Fi Ä‘á»ƒ ghÃ©p Ä‘Ã´i trong CÃ i Ä‘áº·t iPhone, hoáº·c báº¥m 'Nháº­p file pairing (.plist)' á»Ÿ trÃªn.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color(red: 0.18, green: 0.12, blue: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonAmber.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - PIN Code Card
    private var pinCodeCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .foregroundColor(AppTheme.neonAmber)
                Text(isEnglish ? "VERIFICATION PIN" : "MÃƒ PIN XÃC THá»°C GHÃ‰P ÄÃ”I")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonAmber)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(Array(pairing.pinCode), id: \.self) { char in
                    Text(String(char))
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                        .frame(width: 42, height: 50)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.neonCyan.opacity(0.6), lineWidth: 1.5)
                        )
                }
            }
            .padding(.vertical, 4)

            Text(isEnglish ? "Enter this PIN on device if prompted in Settings" : "Nháº­p mÃ£ PIN nÃ y trÃªn mÃ¡y náº¿u má»¥c GhÃ©p Ä‘Ã´i yÃªu cáº§u xÃ¡c nháº­n.")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.10, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonAmber.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Pairing Steps Card
    private var pairingStepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .foregroundColor(AppTheme.neonCyan)
                Text(pairing.hasExistingPairing
                    ? (isEnglish ? "HOW TO APPLY MOD (3 STEPS)" : "CÃCH Náº P MOD (3 BÆ¯á»šC)")
                    : (isEnglish ? "SETUP INSTRUCTIONS" : "HÆ¯á»šNG DáºªN THIáº¾T Láº¬P"))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonCyan)
                Spacer()
            }

            if pairing.hasExistingPairing {
                stepRow(
                    number: 1,
                    title: isEnglish ? "Install & Open Apple Books" : "CÃ i & Má»Ÿ á»¨ng Dá»¥ng SÃ¡ch (Apple Books)",
                    desc: isEnglish ? "AirTraffic sync requires Books app active" : "CÃ i á»©ng dá»¥ng SÃ¡ch tá»« App Store vÃ  má»Ÿ 1 láº§n Ä‘á»ƒ kÃ­ch hoáº¡t AirTraffic"
                )

                stepRow(
                    number: 2,
                    title: isEnglish ? "Turn ON LocalDevVPN" : "Báº­t LocalDevVPN",
                    desc: isEnglish ? "Activate the 10.7.0.1 tunnel interface" : "Báº­t á»©ng dá»¥ng LocalDevVPN Ä‘á»ƒ má»Ÿ tunnel 10.7.0.1 / 10.7.1.1"
                )

                stepRow(
                    number: 3,
                    title: isEnglish ? "Launch Free Fire Game" : "Má»Ÿ Game Free Fire",
                    desc: isEnglish ? "Open game so the container is active" : "Má»Ÿ game lÃªn Ä‘á»ƒ container á»©ng dá»¥ng sáºµn sÃ ng nháº­n tá»‡p mod"
                )

                stepRow(
                    number: 4,
                    title: isEnglish ? "Tap Apply Mod / Anti-Ban" : "Báº¥m Náº¡p Mod / Anti-Ban",
                    desc: isEnglish ? "System conduit writes patches instantly" : "Cáº§u ná»‘i há»‡ thá»‘ng sáº½ ghi patch vÃ  Ã¡p dá»¥ng cheat thÃ nh cÃ´ng!"
                )
            } else {
                stepRow(
                    number: 1,
                    title: isEnglish ? "Open iOS Developer Mode" : "Má»Ÿ CÃ i Äáº·t > Cháº¿ Ä‘á»™ NhÃ  phÃ¡t triá»ƒn",
                    desc: isEnglish ? "Go to Settings -> Privacy & Security -> Developer Mode -> Other Devices" : "VÃ o CÃ i Ä‘áº·t -> Quyá»n riÃªng tÆ° & Báº£o máº­t -> Cháº¿ Ä‘á»™ nhÃ  phÃ¡t triá»ƒn -> CÃ¡c thiáº¿t bá»‹ khÃ¡c"
                )

                stepRow(
                    number: 2,
                    title: isEnglish ? "Tap 'Pair with INNOVA CHEAT'" : "Nháº¥n 'GhÃ©p Ä‘Ã´i vá»›i INNOVA CHEAT'",
                    desc: isEnglish ? "Confirm prompt and enter your device passcode" : "Báº¥m GhÃ©p Ä‘Ã´i vÃ  nháº­p máº­t mÃ£ iPhone Ä‘á»ƒ lÆ°u ghÃ©p Ä‘Ã´i há»‡ thá»‘ng"
                )

                stepRow(
                    number: 3,
                    title: isEnglish ? "Or Import .plist File" : "Hoáº·c Nháº­p File .plist",
                    desc: isEnglish ? "Import pairing record file (.plist) from computer" : "Hoáº·c báº¥m nÃºt 'Nháº­p File Pairing (.plist)' náº¿u báº¡n Ä‘Ã£ cÃ³ file ghÃ©p Ä‘Ã´i"
                )
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Tech Details Card
    private var techDetailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isEnglish ? "CONDUIT DIAGNOSTICS" : "THÃ”NG Sá» Cáº¦U Ná»I")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(pairing.hasExistingPairing ? "FILE PAIRING: Tá»’N Táº I" : "FILE PAIRING: CHÆ¯A CÃ“")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonAmber)
            }

            VStack(alignment: .leading, spacing: 3) {
                techRow(label: "Bonjour Type", value: "_remotepairing-pairable-host._tcp.")
                techRow(label: "Hardware Model", value: "Mac17,7 (Apple Silicon Host)")
                techRow(label: "Loopback Tunnel", value: "\(vpnManager.lastConnectedHost)")
                techRow(label: "Keep-Alive Audio", value: "Active (AVAudioEngine background)")
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            if pairing.hasExistingPairing {
                // NÃºt: Káº¿t ná»‘i VPN & VÃ o game
                Button {
                    Task {
                        _ = await vpnManager.connect()
                    }
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isEnglish ? "ENABLE VPN & ENTER GAME" : "Báº¬T LOCALDEVVPN & VÃ€O GAME")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(AppTheme.neonLime)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.neonLime.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.neonLime.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.badge.arrow.up")
                        Text(isEnglish ? "Import .plist" : "Nháº­p .plist")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.neonCyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                /*
                Button {
                    AppLog.shared.flush()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        Text(isEnglish ? "Export log.txt" : "Xuáº¥t log.txt")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.neonLime)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(AppTheme.neonLime.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                */

                Button {
                    pairing.stopAdvertising()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(isEnglish ? "Close" : "ÄÃ³ng")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Views
    private func statusPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan)
                Text(value)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func stepRow(number: Int, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func techRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
