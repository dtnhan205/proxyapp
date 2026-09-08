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
