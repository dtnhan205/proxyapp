import Foundation

// MARK: - Logging Configuration
// Tự động đồng bộ với `PatchLogConfig.mode` ở GamePatchesView ("dev" -> bật, "public" -> tắt)
private var IS_LOGGING_DISABLED: Bool {
    !PatchLogConfig.isEnabled
}

enum DevicePatchService {
    /// Runtime toggle - only works when IS_LOGGING_DISABLED = false
    static var isLoggingEnabled: Bool = false

    /// Toggle logging on/off at runtime
    static func toggleLogging() {
        isLoggingEnabled.toggle()
    }

    @inline(__always)
    private static func log(_ message: String) {
        if !IS_LOGGING_DISABLED && isLoggingEnabled {
            print("[PATCH] \(message)")
        }
    }

    @inline(__always)
    private static func logInfo(_ message: String) {
        if !IS_LOGGING_DISABLED && isLoggingEnabled {
            print("[PATCH] \(message)")
        }
    }

    @inline(__always)
    private static func logError(_ message: String) {
        if !IS_LOGGING_DISABLED {
            print("[PATCH ERROR] \(message)")
        }
    }

    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        logInfo("Applying project: \(project.name)")
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        logError("App not found: \(bundleID)")
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        logInfo("Restoring receipt: \(receipt.id.uuidString.prefix(8))...")
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        logError("App not found: \(bundleID)")
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    /// Toggle a single rule on/off instantly — no full project transaction needed
    /// because both contents (replacement + original) are bundled in the package.
    static func setRuleState(_ isOn: Bool, rule: PatchRule) throws {
        logInfo("\(isOn ? "Enabling" : "Disabling"): \(rule.relativePath)")
        try withResolvedContainers(bundleIDs: [rule.bundleID]) { roots in
            guard let root = roots[rule.bundleID] else {
                logError("Target app unavailable: \(rule.bundleID)")
                throw PatchPackageError.targetAppUnavailable(rule.bundleID)
            }
            do {
                try PatchTransaction.setRuleState(isOn, rule: rule, containerRoot: root)
                logInfo("SUCCESS: \(isOn ? "Enabled" : "Disabled"): \(rule.relativePath)")
            } catch {
                logError("\(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Read what's currently on disk for this rule and report whether it matches
    /// the replacement (`true`), the original (`false`), or neither (`nil`).
    static func currentRuleState(for rule: PatchRule) -> Bool? {
        try? withResolvedContainers(bundleIDs: [rule.bundleID]) { roots in
            guard let root = roots[rule.bundleID] else { return nil }
            return PatchTransaction.currentRuleState(rule: rule, containerRoot: root)
        }
    }

    /// Kết quả thống kê của một lần auto-restore. Caller dùng để log cho user.
    struct AutoRestoreReport {
        var projectsScanned: Int = 0
        var transactionsRestored: Int = 0
        var rulesReverted: Int = 0
        var skipped: Int = 0
        var failures: [(projectName: String, reason: String)] = []
    }

    /// Revert MỌI patch đang active trên thiết bị về file gốc. Được gọi khi
    /// key hết hạn / bị revoke / build bị revoke — giữ nguyên patch project
    /// trong thư viện + license key trong UserDefaults; user gia hạn key
    /// xong vẫn dùng lại được (toggle sẽ tự apply lại).
    ///
    /// Hai cơ chế restore cùng lúc để cover mọi trường hợp:
    ///   1. **Journal-based**: với mọi project có `latestReceipt` (do
    ///      `PatchTransaction.apply` tạo), gọi `restore(receipt:)` để revert
    ///      files theo backup trong `Backups/{projectID}/{transactionID}/`.
    ///   2. **Rule-based**: với mọi rule còn đang bật (`currentRuleState`),
    ///      gọi `setRuleState(false, rule:)` để restore `originalData` được
    ///      bundle trong rule (hoặc xoá file với VIP / new-file rule).
    ///
    /// Mỗi project được xử lý độc lập — một project lỗi (container không
    /// truy cập được, file gốc đã bị xoá khỏi backup, …) không chặn các
    /// project khác. Kết quả tổng hợp trong `AutoRestoreReport`.
    @discardableResult
    static func restoreAllAppliedPatches() -> AutoRestoreReport {
        let items = PatchProjectLibrary.load()
        var report = AutoRestoreReport()
        report.projectsScanned = items.count
        patchLog("Auto-restore: scanning \(items.count) patch project(s)")

        for item in items {
            let projectName = item.project?.name ?? item.summary.packageID.uuidString

            // 1) Revert theo journal (transaction-based apply)
            if let receipt = latestReceipt(projectID: item.id) {
                do {
                    try restore(receipt: receipt)
                    report.transactionsRestored += 1
                    patchLog("Auto-restore: reverted journal \(receipt.id.uuidString.prefix(8))… for \(projectName)")
                } catch let error as PatchPackageError {
                    let msg = "\(error.localizationKey)\(error.localizationArgument.map { ": \($0)" } ?? "")"
                    report.failures.append((projectName: projectName, reason: "journal: \(msg)"))
                    patchLogError("Auto-restore: journal revert failed for \(projectName) — \(msg)")
                } catch {
                    report.failures.append((projectName: projectName, reason: "journal: \(error.localizedDescription)"))
                    patchLogError("Auto-restore: journal revert failed for \(projectName) — \(error.localizedDescription)")
                }
            }

            // 2) Revert từng rule đang ON (toggle-based patches — không có backup riêng,
            //    nhưng rule đã bundle sẵn originalData nên có thể revert an toàn).
            var project = item.project
            if project == nil {
                if let data = try? PatchProjectLibrary.readPackage(at: item.packageURL) {
                    if item.summary.isPasswordProtected {
                        project = (try? PatchPackageCodec.decode(data, password: PatchPackageCodec.defaultServerPassword))?.project
                    } else {
                        project = (try? PatchPackageCodec.decode(data, password: nil))?.project
                    }
                }
            }
            guard let project else {
                report.skipped += 1
                continue
            }
            for rule in project.rules where rule.canToggle {
                let isOn = currentRuleState(for: rule) == true
                guard isOn else { continue }
                do {
                    try setRuleState(false, rule: rule)
                    report.rulesReverted += 1
                    patchLog("Auto-restore: reverted rule \(rule.relativePath) in \(projectName)")
                } catch let error as PatchPackageError {
                    let msg = "\(error.localizationKey)\(error.localizationArgument.map { ": \($0)" } ?? "")"
                    report.failures.append((projectName: projectName, reason: "rule \(rule.relativePath): \(msg)"))
                    patchLogError("Auto-restore: rule revert failed for \(projectName) — \(msg)")
                } catch {
                    report.failures.append((projectName: projectName, reason: "rule \(rule.relativePath): \(error.localizedDescription)"))
                    patchLogError("Auto-restore: rule revert failed for \(projectName) — \(error.localizedDescription)")
                }
            }
        }

        patchLog("Auto-restore: done — \(report.transactionsRestored) transaction(s), \(report.rulesReverted) rule(s), \(report.failures.count) failure(s), \(report.skipped) skipped")
        AppLog.shared.append("[license] auto-restore: \(report.transactionsRestored) txn, \(report.rulesReverted) rule(s) reverted across \(report.projectsScanned) project(s)")
        if !report.failures.isEmpty {
            for f in report.failures {
                AppLog.shared.append("[license] auto-restore FAIL \(f.projectName): \(f.reason)")
            }
        }
        return report
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]

        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                logError("Cannot resolve container: \(bundleID)")
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
