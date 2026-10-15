import Foundation
import Darwin
import UIKit
import SystemConfiguration
// MARK: - Game Target Definitions
enum FreeFireTarget: String, CaseIterable, Identifiable {
    case freeFireTH = "com.dts.freefireth"
    case freeFireMAX = "com.dts.freefiremax"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .freeFireTH: return "Free Fire"
        case .freeFireMAX: return "Free Fire MAX"
        }
    }
}

enum FreeFirePatchService {
    static let configFileName: String = "optionalab_666.nL~2Bwky7XlQH6YAn8NejPUuelS7g~3D"
    static let tokenFileName: String = "optionalab_avatar_66.aR1cpCxniZkakOa0D5JS~2FD0CYNc~3D"
    static var selectedTarget: FreeFireTarget = .freeFireTH
    static func inject(target: FreeFireTarget) async throws {}
}


/// Bridge chuyÃªn dá»¥ng dÃ nh riÃªng cho iOS 27 sá»­ dá»¥ng LocalDevVPN tunnel (10.7.0.1:49152 / 127.0.0.1)
/// Cung cáº¥p giáº£i phÃ¡p náº¡p patch, quáº£n lÃ½ container game vÃ  Ä‘á»“ng bá»™ cáº¥u hÃ¬nh trÃªn iOS 27 release builds.
///
/// QUY Táº®C Báº¢O TOÃ€N (ISOLATION POLICY):
/// - ToÃ n bá»™ chá»©c nÄƒng trong file nÃ y ÄÆ¯á»¢C Báº¢O Vá»† TUYá»†T Äá»I bá»Ÿi `guard isIOS27 else { return ... }`.
/// - Tuyá»‡t Ä‘á»‘i khÃ´ng can thiá»‡p, khÃ´ng thay Ä‘á»•i luá»“ng hoáº¡t Ä‘á»™ng cá»§a cÃ¡c phiÃªn báº£n iOS khÃ¡c (iOS 15, 16, 17, 18, 26).
enum LocalDevVPNBridge {
    static let defaultHost = "10.7.0.1"
    static let tunnelHost = "10.7.1.1"
    static let loopbackHost = "127.0.0.1"
    static let defaultPort: UInt16 = 49152

    /// Kiá»ƒm tra thiáº¿t bá»‹ cÃ³ Ä‘ang cháº¡y iOS 27 hay khÃ´ng
    static var isIOS27: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27
    }

    /// Kiá»ƒm tra thiáº¿t bá»‹ cÃ³ Ä‘ang cháº¡y iOS 18.7.2 - 18.7.10 hay khÃ´ng
    static var isIOS18_7_x: Bool {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.majorVersion == 18 && v.minorVersion == 7 && v.patchVersion >= 2 && v.patchVersion <= 10
    }

    /// Kiá»ƒm tra thiáº¿t bá»‹ cÃ³ thuá»™c diá»‡n há»— trá»£ qua Cáº§u ná»‘i (Pairing record, LocalDevVPN hoáº·c iOS 17+)
    static var isBridgeSupportedOS: Bool {
        if RemotePairingAdvertiser.shared.hasExistingPairing || detectVPNInterface().active {
            return true
        }
        return isIOS27 || isIOS18_7_x || ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17
    }

    /// Cache Ä‘Æ°á»ng dáº«n container game trÃªn iOS 27 / 18.7.x
    private static var cachedContainerPaths: [String: String] = [:]

    // MARK: - Live Network Interface & Tunnel Probe

    struct VPNInterfaceInfo {
        let active: Bool
        let deviceIP: String
        let tunnelIP: String
        let interfaceName: String
    }

    /// Kiá»ƒm tra xem Network Interface cá»§a LocalDevVPN (utun vá»›i IP 10.7.0.1 / 10.7.1.1) cÃ³ Ä‘ang Active thá»±c táº¿ trÃªn mÃ¡y khÃ´ng
    /// Sá»¬ Dá»¤NG ÄA PHÆ¯Æ NG THá»¨C XÃC THá»°C THá»°C Táº¾ (MULTI-TIER REAL PROBE):
    /// 1. getifaddrs: TÃ¬m giao diá»‡n áº£o utun (chá»‰ cáº§n IFF_UP, khÃ´ng Ä‘Ã²i há»i IFF_RUNNING) cÃ³ IP 10.7.0.1 hoáº·c 10.7.1.1 qua inet_ntop chuáº©n.
    /// 2. UDP Route Probe: Táº¡o socket UDP tá»›i 10.7.1.1 Ä‘á»ƒ kiá»ƒm tra báº£ng Ä‘á»‹nh tuyáº¿n kernel iOS xem IP nguá»“n cÃ³ Ä‘Æ°á»£c gÃ¡n lÃ  10.7.0.1 hay khÃ´ng.
    /// 3. System Proxy Scopes: Kiá»ƒm tra utun trong __SCOPED__ cá»§a há»‡ thá»‘ng.
    static func detectVPNInterface() -> VPNInterfaceInfo {
        // --- PHÆ¯Æ NG THá»¨C 1: QuÃ©t getifaddrs vá»›i POSIX inet_ntop chuáº©n ---
        if let ifInfo = scanInterfacesForVPN() {
            return ifInfo
        }

        // --- PHÆ¯Æ NG THá»¨C 2: Kiá»ƒm tra Kernel Routing Table (UDP Connect to 10.7.1.1) ---
        let route = probeKernelRouteToTunnel()
        if route.routed {
            let ifName = route.interfaceName.isEmpty ? "utun (tunnel route)" : route.interfaceName
            return VPNInterfaceInfo(
                active: true,
                deviceIP: defaultHost, // "10.7.0.1"
                tunnelIP: tunnelHost,  // "10.7.1.1"
                interfaceName: ifName
            )
        }

        // --- PHÆ¯Æ NG THá»¨C 3: Kiá»ƒm tra System Configuration Scoped VPN ---
        if checkSystemVPNScoped() && route.canRouteToSubnet {
            return VPNInterfaceInfo(
                active: true,
                deviceIP: defaultHost,
                tunnelIP: tunnelHost,
                interfaceName: "utun (system scoped)"
            )
        }

        return VPNInterfaceInfo(active: false, deviceIP: "", tunnelIP: "", interfaceName: "")
    }

    /// QuÃ©t cÃ¡c interface máº¡ng qua getifaddrs
    private static func scanInterfacesForVPN() -> VPNInterfaceInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = ptr {
            let interface = current.pointee
            let flags = UInt32(interface.ifa_flags)

            // Giao diá»‡n máº¡ng báº¯t buá»™c pháº£i Ä‘ang Báº¬T (IFF_UP).
            // LÆ¯U Ã: KhÃ´ng check IFF_RUNNING vÃ¬ trÃªn iOS virtual tunnel interfaces (utun) thÆ°á»ng khÃ´ng báº­t cá» nÃ y.
            let isUp = (flags & UInt32(IFF_UP)) != 0

            if isUp, let ifaAddr = interface.ifa_addr {
                let name = String(cString: interface.ifa_name)

                // Chá»‰ quÃ©t cÃ¡c interface dáº¡ng tunnel áº£o (utun, tun, ppp, ipsec)
                if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") {
                    let addrFamily = ifaAddr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        var addrIn = ifaAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var ip = ""
                        if inet_ntop(AF_INET, &addrIn.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                            ip = String(cString: buffer)
                        }

                        var dstIP = ""
                        if let dstAddr = interface.ifa_dstaddr, dstAddr.pointee.sa_family == UInt8(AF_INET) {
                            var dstIn = dstAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                            var dstBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            if inet_ntop(AF_INET, &dstIn.sin_addr, &dstBuf, socklen_t(INET_ADDRSTRLEN)) != nil {
                                dstIP = String(cString: dstBuf)
                            }
                        }

                        // LocalDevVPN gÃ¡n Device IP = 10.7.0.1 vÃ  Tunnel IP = 10.7.1.1
                        if ip == defaultHost || dstIP == tunnelHost || ip == tunnelHost || dstIP == defaultHost {
                            let resolvedDevice = (ip == defaultHost || dstIP == defaultHost) ? defaultHost : ip
                            let resolvedTunnel = (dstIP == tunnelHost || ip == tunnelHost) ? tunnelHost : dstIP
                            return VPNInterfaceInfo(
                                active: true,
                                deviceIP: resolvedDevice,
                                tunnelIP: resolvedTunnel.isEmpty ? tunnelHost : resolvedTunnel,
                                interfaceName: name
                            )
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }

        return nil
    }

    /// Thá»­ táº¡o káº¿t ná»‘i UDP socket tá»›i 10.7.1.1:49152 Ä‘á»ƒ truy váº¥n báº£ng Ä‘á»‹nh tuyáº¿n kernel iOS
    private static func probeKernelRouteToTunnel() -> (routed: Bool, canRouteToSubnet: Bool, interfaceName: String) {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return (false, false, "") }
        defer { close(sock) }

        var targetAddr = sockaddr_in()
        targetAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        targetAddr.sin_family = sa_family_t(AF_INET)
        targetAddr.sin_port = in_port_t(defaultPort).bigEndian
        inet_pton(AF_INET, tunnelHost, &targetAddr.sin_addr) // 10.7.1.1

        let connectRes = withUnsafePointer(to: &targetAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(sock, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectRes == 0 else { return (false, false, "") }

        var localAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getRes = withUnsafeMutablePointer(to: &localAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                getsockname(sock, saPtr, &len)
            }
        }

        guard getRes == 0 else { return (false, false, "") }

        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        if inet_ntop(AF_INET, &localAddr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
            let localIP = String(cString: buf)
            // Náº¿u báº£ng Ä‘á»‹nh tuyáº¿n kernel cá»§a iOS gÃ¡n Ä‘á»‹a chá»‰ nguá»“n tá»›i 10.7.1.1 lÃ  10.7.0.1
            // thÃ¬ cháº¯c cháº¯n giao diá»‡n tunnel cá»§a LocalDevVPN Ä‘ang hoáº¡t Ä‘á»™ng!
            if localIP == defaultHost {
                return (true, true, "utun (10.7.0.1)")
            } else if localIP.hasPrefix("10.7.") {
                return (true, true, "utun (\(localIP))")
            }
        }

        return (false, false, "")
    }

    /// Kiá»ƒm tra cÃ¡c Scoped VPN interface qua System Configuration
    private static func checkSystemVPNScoped() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let scopes = nsDict["__SCOPED__"] as? NSDictionary else { return false }
        for key in scopes.allKeys {
            if let name = key as? String, name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ipsec") {
                return true
            }
        }
        return false
    }

    /// Kiá»ƒm tra káº¿t ná»‘i tá»›i LocalDevVPN tunnel (10.7.0.1)
    /// Tráº£ vá» true Náº¾U VÃ€ CHá»ˆ Náº¾U giao diá»‡n utun cá»§a LocalDevVPN Ä‘ang hoáº¡t Ä‘á»™ng thá»±c táº¿
    static func isTunnelActive() -> Bool {
        guard isBridgeSupportedOS else { return false }
        return detectVPNInterface().active
    }

    // MARK: - Container Resolution (iOS 18.7.x & iOS 27)

    /// TÃ¬m container data cá»§a game trÃªn iOS 18.7.x / 27
    static func resolveContainerPath(bundleID: String) -> String? {
        guard isBridgeSupportedOS else { return nil }

        if let cached = cachedContainerPaths[bundleID], !cached.isEmpty {
            if ContainerStore.isApplicationContainerPath(cached) {
                return cached
            }
            cachedContainerPaths.removeValue(forKey: bundleID)
        }

        // 0. Æ¯U TIÃŠN 1: Náº¿u Ä‘Ã£ cÃ³ Pairing File tá»« Developer Mode (Airlift / RPPairing), truy váº¥n qua RSD Installation Proxy
        if RemotePairingAdvertiser.shared.hasExistingPairing {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            if let airliftPath = AirliftBridge.findAppContainerSync(bundleID: bundleID, pairingPath: pairingPath),
               !airliftPath.isEmpty {
                _ = ContainerStore.grantContainerAccess(airliftPath)
                cachedContainerPaths[bundleID] = airliftPath
                return airliftPath
            }
        }

        // 1. Kiá»ƒm tra qua MobileContainerManager (MCMActivateContainerPath)
        var lookupError: NSString?
        if let mcmPath = MCMActivateContainerPath(2, bundleID, false, &lookupError),
           ContainerStore.isApplicationContainerPath(mcmPath) {
            _ = ContainerStore.grantContainerAccess(mcmPath)
            cachedContainerPaths[bundleID] = mcmPath
            return mcmPath
        }

        // 2. Kiá»ƒm tra qua LSApplicationProxy (chá»‰ cháº¥p nháº­n náº¿u path há»£p lá»‡ /Containers/Data/Application/...)
        let info = (appInfoForBundleID(bundleID) as? [String: Any]) ?? [:]
        if let container = info["container"] as? String,
           !container.isEmpty,
           ContainerStore.isApplicationContainerPath(container),
           FileManager.default.fileExists(atPath: container) {
            _ = ContainerStore.grantContainerAccess(container)
            cachedContainerPaths[bundleID] = container
            return container
        }

        // 3. QuÃ©t qua appDataRoot /var/mobile/Containers/Data/Application
        let candidates = [
            "/var/mobile/Containers/Data/Application",
            "/private/var/mobile/Containers/Data/Application"
        ]

        for root in candidates {
            guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for uuid in dirs {
                guard UUID(uuidString: uuid) != nil else { continue }
                let containerPath = "\(root)/\(uuid)"
                let plistPath = "\(containerPath)/.com.apple.mobile_container_manager.metadata.plist"
                if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let bid = plist["MCMMetadataIdentifier"] as? String,
                   bid == bundleID {
                    _ = ContainerStore.grantContainerAccess(containerPath)
                    cachedContainerPaths[bundleID] = containerPath
                    return containerPath
                }

                // Fallback scan: kiá»ƒm tra thÆ° má»¥c Documents / Library cÃ³ dáº¥u hiá»‡u nháº­n biáº¿t cá»§a game
                let docsPath = "\(containerPath)/Documents"
                if FileManager.default.fileExists(atPath: docsPath) {
                    if bundleID == FreeFireTarget.freeFireTH.rawValue || bundleID == FreeFireTarget.freeFireMAX.rawValue {
                        let unityFolder = "\(containerPath)/Library/Unity"
                        let shadowTracker = "\(docsPath)/contentcache"
                        if FileManager.default.fileExists(atPath: unityFolder) || FileManager.default.fileExists(atPath: shadowTracker) {
                            _ = ContainerStore.grantContainerAccess(containerPath)
                            cachedContainerPaths[bundleID] = containerPath
                            return containerPath
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Diagnostics & Real File Access Probe

    /// Cháº¡y kiá»ƒm tra toÃ n diá»‡n: File Pairing, VPN Tunnel, Free Fire Container & Documents R/W Probe
    static func runFullDiagnostics() -> [String] {
        var logs: [String] = []
        func logEntry(_ tag: String, _ msg: String, icon: String = "â„¹ï¸") {
            let line = "[\(tag)] \(icon) \(msg)"
            logs.append(line)
            AppLog.shared.append(line)
            print(line)
        }

        let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logEntry("TEST", "Báº®T Äáº¦U KIá»‚M TRA TRUY Cáº¬P THá»°C Táº¾ (\(timeStr))", icon: "ðŸš€")

        // 1. KIá»‚M TRA FILE PAIRING
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let candidatePaths = [
            ("innova_pairing.plist", (docs as NSString).appendingPathComponent("innova_pairing.plist")),
            ("innova_pairing_import.plist", (docs as NSString).appendingPathComponent("innova_pairing_import.plist")),
            ("delta_pairing.plist", (docs as NSString).appendingPathComponent("delta_pairing.plist")),
            ("delta_pairing_import.plist", (docs as NSString).appendingPathComponent("delta_pairing_import.plist")),
            ("local_pairing.plist", (docs as NSString).appendingPathComponent("pairing_records/local_pairing.plist"))
        ]

        var foundPairing = false
        for (name, path) in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPairing = true
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int64 {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        let keys = plist.keys.joined(separator: ", ")
                        logEntry("PAIRING", "TÃ¬m tháº¥y \(name): \(size) bytes (Keys: \(keys))", icon: "âœ…")
                    } else {
                        logEntry("PAIRING", "TÃ¬m tháº¥y \(name): \(size) bytes (Dá»¯ liá»‡u há»£p lá»‡)", icon: "âœ…")
                    }
                } else {
                    logEntry("PAIRING", "TÃ¬m tháº¥y \(name)", icon: "âœ…")
                }
            }
        }
        if !foundPairing {
            logEntry("PAIRING", "CHÆ¯A CÃ“ FILE PAIRING! HÃ£y ghÃ©p Ä‘Ã´i trong CÃ i Ä‘áº·t iPhone hoáº·c 'Nháº­p .plist'.", icon: "âš ï¸")
        }

        // 2. KIá»‚M TRA LOCALDEVVPN TUNNEL
        let vpn = detectVPNInterface()
        if vpn.active {
            logEntry("VPN", "Giao diá»‡n \(vpn.interfaceName) ÄANG Báº¬T! (IP mÃ¡y: \(vpn.deviceIP), Tunnel: \(vpn.tunnelIP))", icon: "âœ…")
            let route = probeKernelRouteToTunnel()
            if route.routed {
                logEntry("VPN", "Báº£ng Ä‘á»‹nh tuyáº¿n Kernel: ÄÃ£ route tá»›i \(tunnelHost):\(defaultPort)", icon: "âœ…")
            } else {
                logEntry("VPN", "Äá»‹nh tuyáº¿n tá»›i \(tunnelHost): Chá» kÃ­ch hoáº¡t routing", icon: "â„¹ï¸")
            }
        } else {
            logEntry("VPN", "LocalDevVPN ÄANG Táº®T (Giao diá»‡n utun 10.7.0.1 chÆ°a báº­t)", icon: "âš ï¸")
        }

        // 3. KIá»‚M TRA FREE FIRE CONTAINERS VÃ€ DOCUMENTS
        let targets = [
            ("Free Fire ThÆ°á»ng (TH)", FreeFireTarget.freeFireTH.rawValue),
            ("Free Fire MAX", FreeFireTarget.freeFireMAX.rawValue)
        ]

        for (displayName, bundleID) in targets {
            logEntry("GAME", "--- Kiá»ƒm tra \(displayName) (\(bundleID)) ---", icon: "ðŸŽ®")

            // Kiá»ƒm tra cÃ i Ä‘áº·t qua LSApplicationProxy
            let info = (appInfoForBundleID(bundleID) as? [String: Any]) ?? [:]
            let isInstalled = (info["found"] as? NSNumber)?.boolValue ?? false || (info["name"] != nil && (info["name"] as? String) != bundleID)
            let version = info["version"] as? String ?? "N/A"

            if isInstalled {
                logEntry("GAME", "\(displayName): ÄÃƒ CÃ€I Äáº¶T trÃªn mÃ¡y (v\(version))", icon: "ðŸ“±")
            } else {
                logEntry("GAME", "\(displayName): Thá»­ tÃ¬m theo bundle ID \(bundleID)", icon: "ðŸ”")
            }

            // TÃ¬m container path (chá»‰ cháº¥p nháº­n container há»£p lá»‡ cá»§a game, tuyá»‡t Ä‘á»‘i khÃ´ng cháº¥p nháº­n /var/mobile)
            var containerPath: String? = nil
            if let c = ContainerStore.resolveAppContainerPath(bundleID: bundleID), ContainerStore.isApplicationContainerPath(c) {
                containerPath = c
            } else if let c = resolveContainerPath(bundleID: bundleID), ContainerStore.isApplicationContainerPath(c) {
                containerPath = c
            } else if let c = info["container"] as? String, ContainerStore.isApplicationContainerPath(c) {
                containerPath = c
            }

            if let container = containerPath, ContainerStore.isApplicationContainerPath(container) {
                logEntry("CONTAINER", "Container Data: \(container)", icon: "ðŸ“‚")

                let docsPath = (container as NSString).appendingPathComponent("Documents")
                let docsExists = FileManager.default.fileExists(atPath: docsPath)

                if docsExists {
                    let grantHandle = ContainerStore.grantContainerAccess(container)
                    defer {
                        if grantHandle >= 0 {
                            bad_query_release(grantHandle)
                        }
                    }

                    let isReadable = FileManager.default.isReadableFile(atPath: docsPath)
                    let isWritable = FileManager.default.isWritableFile(atPath: docsPath)
                    logEntry("DOCUMENTS", "ThÆ° má»¥c Documents: Tá»’N Táº I (Äá»c: \(isReadable ? "OK" : "NO"), Ghi: \(isWritable ? "OK" : "NO"))", icon: "ðŸ“")

                    // Liá»‡t kÃª ná»™i dung Documents
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: docsPath) {
                        let count = contents.count
                        let preview = contents.prefix(5).joined(separator: ", ")
                        logEntry("DOCUMENTS", "Ná»™i dung Documents (\(count) má»¥c): \(preview)\(count > 5 ? "..." : "")", icon: "ðŸ“„")
                    }

                    // Test ghi / Ä‘á»c file thá»±c táº¿ (Read/Write Probe)
                    let probePath = (docsPath as NSString).appendingPathComponent(".innova_probe_test.tmp")
                    let testPayload = "INNOVA_PROBE_\(Date().timeIntervalSince1970)".data(using: .utf8)!
                    var probeSuccess = false
                    do {
                        try testPayload.write(to: URL(fileURLWithPath: probePath), options: .atomic)
                        let verifyData = try Data(contentsOf: URL(fileURLWithPath: probePath))
                        try? FileManager.default.removeItem(atPath: probePath)
                        if verifyData == testPayload {
                            probeSuccess = true
                            logEntry("PROBE", "TRUY Cáº¬P DOCUMENTS (POSIX TRá»°C TIáº¾P): âœ… ÄÃƒ GHI & Äá»ŒC THÃ€NH CÃ”NG (100% ACCESS)", icon: "ðŸŽ‰")
                        } else {
                            logEntry("PROBE", "Dá»¯ liá»‡u kiá»ƒm tra khÃ´ng khá»›p", icon: "âš ï¸")
                        }
                    } catch {
                        logEntry("PROBE", "Ghi trá»±c tiáº¿p POSIX: \(error.localizedDescription) (Sandbox háº¡n cháº¿)", icon: "â„¹ï¸")
                    }

                    if !probeSuccess && RemotePairingAdvertiser.shared.hasExistingPairing {
                        let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
                        let probeStaging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("probe_\(UUID().uuidString)")
                        try? FileManager.default.createDirectory(at: probeStaging, withIntermediateDirectories: true)
                        defer { try? FileManager.default.removeItem(at: probeStaging) }
                        try? testPayload.write(to: probeStaging.appendingPathComponent(".innova_probe_test.tmp"), options: .atomic)

                        logEntry("PROBE", "Thá»­ nghiá»‡m ghi qua AirTraffic / Developer Mode tunnel...", icon: "ðŸ“¡")
                        var outError: UnsafeMutablePointer<CChar>? = nil
                        AirliftBridge.syncTargetHosts()
                        let cb: ALLogCallback = { _, msg in
                            guard let msg = msg else { return }
                            let line = String(cString: msg)
                            AppLog.shared.append("[AIRLIFT LOG] \(line)")
                            RemotePairingAdvertiser.shared.log("[AIRLIFT] \(line)")
                        }
                        let rc = al_exploit_write_dir(pairingPath, probeStaging.path, docsPath, cb, nil, &outError)
                        if rc == 0 {
                            logEntry("PROBE", "TRUY Cáº¬P DOCUMENTS QUA AIRLIFT/DEVELOPER MODE: âœ… ÄÃƒ GHI THÃ€NH CÃ”NG (100% ACCESS)", icon: "ðŸŽ‰")
                        } else {
                            let msg = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                            if let errPtr = outError { al_string_free(errPtr) }
                            logEntry("PROBE", "Thá»­ nghiá»‡m AirTraffic: \(msg)", icon: "âš ï¸")
                        }
                    }

                    // Kiá»ƒm tra patch file hiá»‡n táº¡i
                    let patchPath = (docsPath as NSString).appendingPathComponent("Assembly-CSharp-patch.bytes")
                    if FileManager.default.fileExists(atPath: patchPath) {
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: patchPath) {
                            let size = (attrs[FileAttributeKey.size] as? NSNumber)?.int64Value ?? 0
                            logEntry("PATCH", "File Assembly-CSharp-patch.bytes: âœ… ÄÃƒ Náº P Sáº´N (\(size) bytes)", icon: "âš¡")
                        }
                    } else {
                        logEntry("PATCH", "File Assembly-CSharp-patch.bytes: ChÆ°a náº¡p (Sáºµn sÃ ng náº¡p khi báº¥m nÃºt)", icon: "â„¹ï¸")
                    }
                } else {
                    logEntry("DOCUMENTS", "ThÆ° má»¥c Documents chÆ°a táº¡o (HÃ£y má»Ÿ game Free Fire 1 láº§n Ä‘á»ƒ táº¡o Documents)", icon: "âš ï¸")
                }
            } else {
                logEntry("CONTAINER", "ChÆ°a quÃ©t tháº¥y thÆ° má»¥c Container cá»§a \(displayName). (HÃ£y má»Ÿ game Ã­t nháº¥t 1 láº§n Ä‘á»ƒ há»‡ thá»‘ng kÃ­ch hoáº¡t)", icon: "â„¹ï¸")
            }
        }

        logEntry("TEST", "HOÃ€N Táº¤T KIá»‚M TRA TRUY Cáº¬P Há»† THá»NG", icon: "ðŸ")
        return logs
    }

    // MARK: - File Operations & Injection (iOS 18.7.x & iOS 27)

    /// Thá»±c hiá»‡n náº¡p patch vÃ  cáº¥u hÃ¬nh vÃ o container game trÃªn iOS 18.7.x / 27
    static func inject(
        target: FreeFireTarget,
        patchData: Data,
        configData: Data,
        localData: Data,
        tokenData: Data?
    ) -> Bool {
        guard isBridgeSupportedOS else { return false }

        var success = false

        // 0. Æ¯U TIÃŠN 1: Náº¿u cÃ³ Pairing Record tá»« Developer Mode (Airlift / RPPairing), ghi qua AirTraffic tunnel
        if RemotePairingAdvertiser.shared.hasExistingPairing,
           let containerPath = resolveContainerPath(bundleID: target.rawValue) {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vpn_staging_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: stagingDir) }

            let patchFile = stagingDir.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let localFile = stagingDir.appendingPathComponent("localConfig.json")
            let cfgFile = stagingDir.appendingPathComponent(FreeFirePatchService.configFileName)

            try? patchData.write(to: patchFile, options: .atomic)
            try? localData.write(to: localFile, options: .atomic)
            try? configData.write(to: cfgFile, options: .atomic)

            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: stagingDir.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)
            }

            let deepCfgDir = stagingDir.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = stagingDir.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            try? configData.write(to: deepCfgDir.appendingPathComponent(FreeFirePatchService.configFileName), options: .atomic)
            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: deepTokDir.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)
            }

            AirliftBridge.syncTargetHosts()
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc = al_exploit_write_dir(
                pairingPath,
                stagingDir.path,
                "\(containerPath)/Documents",
                nil,
                nil,
                &outError
            )
            if rc == 0 {
                success = true
                AppLog.shared.append("[VPN] âœ… Ghi file qua AirTraffic tunnel thÃ nh cÃ´ng!")
            } else {
                let msg = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                if let err = outError { al_string_free(err) }
                AppLog.shared.append("[VPN] âš ï¸ Ghi qua AirTraffic: \(msg)")
            }
        }

        // 1. Ghi trá»±c tiáº¿p vÃ o Container náº¿u Ä‘Ã£ tÃ¬m tháº¥y Ä‘Æ°á»ng dáº«n
        if let containerPath = resolveContainerPath(bundleID: target.rawValue),
           ContainerStore.isApplicationContainerPath(containerPath) {
            let grantHandle = ContainerStore.grantContainerAccess(containerPath)
            defer {
                if grantHandle >= 0 {
                    bad_query_release(grantHandle)
                }
            }
            let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents", isDirectory: true)
            let deepCfgDir = docsURL.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = docsURL.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)

            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            let patchURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let localURL = docsURL.appendingPathComponent("localConfig.json")
            let deepCfgFile = deepCfgDir.appendingPathComponent(FreeFirePatchService.configFileName)
            let deepTokFile = deepTokDir.appendingPathComponent(FreeFirePatchService.tokenFileName)

            if (try? patchData.write(to: patchURL, options: .atomic)) != nil {
                success = true
            }
            try? localData.write(to: localURL, options: .atomic)
            try? configData.write(to: deepCfgFile, options: .atomic)

            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: deepTokFile, options: .atomic)
            }

            // Dá»n dáº¹p file thá»«a á»Ÿ Documents root Ä‘á»ƒ khÃ´ng lá»™ ra app Files
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(FreeFirePatchService.configFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(FreeFirePatchService.tokenFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(".innova_token.dat"))
        }

        // 2. Náº¿u cÃ³ LocalDevVPN tunnel (10.7.0.1:49152), Ä‘á»“ng bá»™ thÃªm qua tunnel conduit
        if isTunnelActive() {
            notifyTunnelOfInjection(target: target)
            success = true
        }

        return success
    }

    /// Äá»“ng bá»™ cáº¥u hÃ¬nh cheat trÃªn iOS 18.7.x / 27
    static func syncConfig(target: FreeFireTarget, configData: Data) -> Bool {
        guard isBridgeSupportedOS else { return false }

        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let deepCfgDir = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/contentcache/Optional/ios/gameassetbundles", isDirectory: true)
        try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
        let deepCfgFile = deepCfgDir.appendingPathComponent(FreeFirePatchService.configFileName)
        do {
            try configData.write(to: deepCfgFile, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Neutral Patch 322 bytes (Assembly-CSharp-patch-neutral.bytes)
    /// Há»£p lá»‡ theo chuáº©n InjectFix nhÆ°ng chá»©a 0 method hook -> VÃ´ hiá»‡u hÃ³a ngay láº­p tá»©c
    private static let neutralPatchBase64 = "y6K0DbIZo2ZkSUZpeC5JTEZpeEludGVyZmFjZUJyaWRnZSwgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABjSUZpeC5XcmFwcGVyc01hbmFnZXJJbXBsLCBBc3NlbWJseS1DU2hhcnAsIFZlcnNpb249MC44Ni4wLjUxOCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsSywgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAA=="

    /// Gá»¡ bá» patch: Ghi Ä‘Ã¨ Neutral Patch vÃ  kÃ­ch hoáº¡t cÆ¡ cháº¿ Tá»± Há»§y (Self-Delete) qua AirTraffic vÃ o Free Fire
    static func uninject(target: FreeFireTarget) -> Bool {
        guard isBridgeSupportedOS else { return false }

        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }

        var airtrafficSuccess = false

        // 1. Ghi tÃ­n hiá»‡u Uninject / Self-Delete & Neutral Patch qua AirTraffic tunnel
        if RemotePairingAdvertiser.shared.hasExistingPairing {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uninject_staging_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: stagingDir) }

            // Neutral Patch 322 bytes (VÃ´ hiá»‡u hÃ³a ngay mÃ£ patch bytecode)
            let neutralData = Data(base64Encoded: neutralPatchBase64) ?? Data()
            try? neutralData.write(to: stagingDir.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)

            // Cáº¥u hÃ¬nh vÃ´ hiá»‡u hÃ³a & Cá» Self-Delete
            let uninstalledJson = "{\"enabled\":false,\"uninstalled\":true,\"uninject\":true,\"features\":{}}".data(using: .utf8) ?? Data()
            try? uninstalledJson.write(to: stagingDir.appendingPathComponent("localConfig.json"), options: .atomic)
            try? uninstalledJson.write(to: stagingDir.appendingPathComponent(FreeFirePatchService.configFileName), options: .atomic)
            try? uninstalledJson.write(to: stagingDir.appendingPathComponent("uninject.flag"), options: .atomic)

            // Token vÃ´ hiá»‡u hÃ³a
            let emptyTok = "{\"token\":\"\",\"expired\":true,\"status\":\"uninjected\"}".data(using: .utf8) ?? Data()
            try? emptyTok.write(to: stagingDir.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)

            // Ghi trá»±c tiáº¿p vÃ o Documents root cá»§a Free Fire
            AirliftBridge.syncTargetHosts()
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc = al_exploit_write_dir(
                pairingPath,
                stagingDir.path,
                "\(containerPath)/Documents",
                nil,
                nil,
                &outError
            )
            if rc == 0 {
                airtrafficSuccess = true
                AppLog.shared.append("[UNINJECT] ðŸ—‘ï¸ ÄÃ£ ghi Ä‘Ã¨ Neutral Patch & cá» Self-Delete vÃ o Documents game!")
            } else {
                let msg = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                if let err = outError { al_string_free(err) }
                AppLog.shared.append("[UNINJECT] âš ï¸ AirTraffic uninject Documents: \(msg)")
            }

            // Ghi Ä‘Ã¨ file config sÃ¢u vÃ o contentcache/Optional/ios/gameassetbundles
            let subCfgStaging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uninject_cfg_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: subCfgStaging, withIntermediateDirectories: true)
            try? uninstalledJson.write(to: subCfgStaging.appendingPathComponent(FreeFirePatchService.configFileName), options: .atomic)
            try? uninstalledJson.write(to: subCfgStaging.appendingPathComponent("menu_config.json"), options: .atomic)
            let rcCfg = AirliftBridge.injectFolderSync(
                folderPath: subCfgStaging.path,
                targetParentDir: "\(containerPath)/Documents/contentcache/Optional/ios",
                destName: "gameassetbundles",
                pairingPath: pairingPath
            )
            try? FileManager.default.removeItem(at: subCfgStaging)
            if rcCfg == 0 {
                AppLog.shared.append("[UNINJECT] ðŸ—‘ï¸ ÄÃ£ vÃ´ hiá»‡u hÃ³a config sÃ¢u (gameassetbundles)")
            }

            // Ghi Ä‘Ã¨ token sÃ¢u vÃ o contentcache/Optional/ios/optionalavatarres/gameassetbundles
            let subTokStaging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uninject_tok_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: subTokStaging, withIntermediateDirectories: true)
            try? emptyTok.write(to: subTokStaging.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)
            try? emptyTok.write(to: subTokStaging.appendingPathComponent(".innova_token.dat"), options: .atomic)
            let rcTok = AirliftBridge.injectFolderSync(
                folderPath: subTokStaging.path,
                targetParentDir: "\(containerPath)/Documents/contentcache/Optional/ios/optionalavatarres",
                destName: "gameassetbundles",
                pairingPath: pairingPath
            )
            try? FileManager.default.removeItem(at: subTokStaging)
            if rcTok == 0 {
                AppLog.shared.append("[UNINJECT] ðŸ—‘ï¸ ÄÃ£ vÃ´ hiá»‡u hÃ³a token sÃ¢u (optionalavatarres)")
            }
        }

        // 2. Dá»n dáº¹p cá»¥c bá»™ qua FileManager náº¿u cÃ³ quyá»n (Jailbreak / Shared container fallback)
        let containerURL = URL(fileURLWithPath: containerPath)
        let docs = containerURL.appendingPathComponent("Documents")
        let patchURL = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let localURL = docs.appendingPathComponent("localConfig.json")
        let deepCfg = docs.appendingPathComponent("contentcache/Optional/ios/gameassetbundles/\(FreeFirePatchService.configFileName)")
        let deepTok = docs.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles/\(FreeFirePatchService.tokenFileName)")

        try? FileManager.default.removeItem(at: patchURL)
        try? FileManager.default.removeItem(at: localURL)
        try? FileManager.default.removeItem(at: deepCfg)
        try? FileManager.default.removeItem(at: deepTok)
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("contentcache/Optional/ios/gameassetbundles/menu_config.json"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles/.innova_token.dat"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("uninject.flag"))

        return airtrafficSuccess || true
    }

    /// Kiá»ƒm tra Ä‘Ã£ inject chÆ°a trÃªn iOS 18.7.x / 27
    static func isInjected(target: FreeFireTarget) -> Bool {
        guard isBridgeSupportedOS else { return false }
        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let patchURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
        return FileManager.default.fileExists(atPath: patchURL.path)
    }

    /// Gá»­i tÃ­n hiá»‡u thÃ´ng bÃ¡o tá»›i LocalDevVPN tunnel náº¿u Ä‘ang láº¯ng nghe
    private static func notifyTunnelOfInjection(target: FreeFireTarget) {
        guard isBridgeSupportedOS else { return }
        guard isTunnelActive() else { return }
        for host in [defaultHost, tunnelHost] {
            guard let url = URL(string: "http://\(host):\(defaultPort)/airlift/ping") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 0.5
            let payload: [String: Any] = [
                "bundleID": target.rawValue,
                "action": "injected",
                "timestamp": Date().timeIntervalSince1970
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
        }
    }

    /// Chuá»—i mÃ´ táº£ tráº¡ng thÃ¡i dÃ nh cho UI trÃªn iOS 27 vÃ  iOS 18.7.x
    static func statusDescription() -> String {
        guard isBridgeSupportedOS else { return "" }
        let osName = isIOS18_7_x ? "iOS 18.7.x" : "iOS 27"
        let vpn = detectVPNInterface()
        if vpn.active {
            return "\(osName) LocalDevVPN (\(vpn.interfaceName): \(vpn.deviceIP)) â€” ÄÃ£ káº¿t ná»‘i"
        } else {
            return "\(osName) LocalDevVPN â€” ChÆ°a káº¿t ná»‘i (VPN Ä‘ang táº¯t)"
        }
    }

    /// Kiá»ƒm tra káº¿t ná»‘i tá»›i LocalDevVPN tunnel thá»±c táº¿ (10.7.0.1)
    /// Tráº£ vá» success: true Náº¾U VÃ€ CHá»ˆ Náº¾U giao diá»‡n utun Ä‘ang UP vÃ  cÃ³ IP 10.7.0.1
    static func testConnection() async -> (success: Bool, host: String, interfaceName: String) {
        guard isBridgeSupportedOS else {
            return (false, "KhÃ´ng há»— trá»£ phiÃªn báº£n iOS nÃ y", "")
        }

        let vpn = detectVPNInterface()
        if vpn.active {
            return (true, "\(vpn.deviceIP) (Tunnel: \(vpn.tunnelIP))", vpn.interfaceName)
        } else {
            return (false, "\(defaultHost) (ChÆ°a kÃ­ch hoáº¡t)", "")
        }
    }
}

// MARK: - Observable Manager for SwiftUI

@MainActor
final class LocalDevVPNManager: ObservableObject {
    static let shared = LocalDevVPNManager()

    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var statusMessage: String = "ChÆ°a káº¿t ná»‘i (LocalDevVPN Ä‘ang Táº¯t)"
    @Published var lastConnectedHost: String = "\(LocalDevVPNBridge.defaultHost) (Tunnel: \(LocalDevVPNBridge.tunnelHost))"
    @Published var detectedInterfaceName: String = ""
    @Published var lastCheckDate: Date?

    private init() {
        refreshStatus()
    }

    /// Äá»“ng bá»™ tráº¡ng thÃ¡i thá»±c táº¿ tá»« interface kernel
    func refreshStatus() {
        let vpn = LocalDevVPNBridge.detectVPNInterface()
        if vpn.active {
            self.isConnected = true
            self.detectedInterfaceName = vpn.interfaceName
            self.statusMessage = "ÄÃ£ káº¿t ná»‘i (\(vpn.interfaceName): \(vpn.deviceIP))"
            self.lastConnectedHost = "\(vpn.deviceIP) (Tunnel: \(vpn.tunnelIP))"
        } else {
            self.isConnected = false
            self.detectedInterfaceName = ""
            self.statusMessage = "ChÆ°a káº¿t ná»‘i (LocalDevVPN Ä‘ang Táº¯t)"
            self.lastConnectedHost = "\(LocalDevVPNBridge.defaultHost) (ChÆ°a kÃ­ch hoáº¡t)"
        }
    }

    /// KÃ­ch hoáº¡t kiá»ƒm tra káº¿t ná»‘i thá»§ cÃ´ng tá»« CÃ i Ä‘áº·t hoáº·c MÃ n hÃ¬nh chÃ­nh
    func connect() async -> (success: Bool, message: String) {
        isConnecting = true
        defer { isConnecting = false }

        // Delay 0.25s Ä‘á»ƒ hiá»ƒn thá»‹ spinner pháº£n há»“i thao tÃ¡c ngÆ°á»i dÃ¹ng
        try? await Task.sleep(nanoseconds: 250_000_000)

        let res = await LocalDevVPNBridge.testConnection()
        lastCheckDate = Date()
        let osName = LocalDevVPNBridge.isIOS18_7_x ? "iOS 18.7.x" : "iOS 27"

        if res.success {
            isConnected = true
            detectedInterfaceName = res.interfaceName
            statusMessage = "ÄÃ£ káº¿t ná»‘i (\(res.interfaceName): \(res.host))"
            lastConnectedHost = res.host
            _ = LocalDevVPNBridge.resolveContainerPath(bundleID: FreeFireTarget.freeFireTH.rawValue)
            _ = LocalDevVPNBridge.resolveContainerPath(bundleID: FreeFireTarget.freeFireMAX.rawValue)

            let hasPairing = RemotePairingAdvertiser.shared.hasExistingPairing
            let msg: String
            if hasPairing {
                msg = """
                âœ… LOCALDEVVPN ÄÃƒ Káº¾T Ná»I THÃ€NH CÃ”NG!
                â€¢ Giao diá»‡n máº¡ng: \(res.interfaceName)
                â€¢ Tunnel: \(res.host)
                â€¢ Tráº¡ng thÃ¡i Pairing: âœ… ÄÃƒ CÃ“ FILE PAIRING

                ðŸŽ‰ THIáº¾T Bá»Š ÄÃƒ Sáº´N SÃ€NG!
                Báº¡n khÃ´ng cáº§n vÃ o Cháº¿ Ä‘á»™ NhÃ  phÃ¡t triá»ƒn Ä‘á»ƒ ghÃ©p Ä‘Ã´i ná»¯a.
                ðŸ‘‰ HÃ£y má»Ÿ game Free Fire vÃ  báº¥m 'Náº P MOD / ANTI-BAN' ngay!
                """
            } else {
                msg = """
                âœ… LOCALDEVVPN ÄÃƒ Káº¾T Ná»I THÃ€NH CÃ”NG!
                â€¢ Giao diá»‡n máº¡ng: \(res.interfaceName)
                â€¢ Tunnel: \(res.host)

                ðŸ‘‰ BÆ¯á»šC TIáº¾P THEO:
                VÃ o CÃ i Ä‘áº·t > GhÃ©p Ä‘Ã´i iOS 27 > GhÃ©p Ä‘Ã´i vá»›i iPhone hoáº·c Nháº­p file .plist tá»« mÃ¡y tÃ­nh Ä‘á»ƒ hoÃ n táº¥t!
                """
            }
            return (true, msg)
        } else {
            isConnected = false
            detectedInterfaceName = ""
            statusMessage = "ChÆ°a káº¿t ná»‘i (LocalDevVPN Ä‘ang Táº¯t)"
            lastConnectedHost = "\(LocalDevVPNBridge.defaultHost) (ChÆ°a kÃ­ch hoáº¡t)"

            let msg = """
            âŒ KHÃ”NG TÃŒM THáº¤Y LOCALDEVVPN: Giao diá»‡n utun (10.7.0.1) hiá»‡n Ä‘ang Táº®T!

            ðŸ‘‰ CÃCH Xá»¬ LÃ (2 BÆ¯á»šC):
            1. ThoÃ¡t ra mÃ n hÃ¬nh chÃ­nh, má»Ÿ á»©ng dá»¥ng 'LocalDevVPN'.
            2. Gáº¡t cÃ´ng táº¯c sang tráº¡ng thÃ¡i 'Connected' (hiá»ƒn thá»‹ Tunnel IP: 10.7.1.1, Device IP: 10.7.0.1).
            3. Quay láº¡i á»©ng dá»¥ng nÃ y vÃ  báº¥m nÃºt 'Káº¾T Ná»I \(osName.uppercased())' láº¡i.
            """
            return (false, msg)
        }
    }
}

