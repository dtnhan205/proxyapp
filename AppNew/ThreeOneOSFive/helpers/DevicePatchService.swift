import Foundation
import SwiftUI

enum DevicePatchService {
    /// Toggle logging for patch operations. When false, print statements are skipped.
    static var isLoggingEnabled: Bool = true
    
    private static func log(_ message: String) {
        if isLoggingEnabled {
            print("[PATCH] \(message)")
        }
    }
    
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        log("Applying project: \(project.name)")
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        log("ERROR: App not found: \(bundleID)")
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        log("Restoring receipt: \(receipt.id.uuidString.prefix(8))...")
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        log("ERROR: App not found: \(bundleID)")
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
        log("\(isOn ? "Enabling" : "Disabling"): \(rule.relativePath)")
        try withResolvedContainers(bundleIDs: [rule.bundleID]) { roots in
            guard let root = roots[rule.bundleID] else {
                log("ERROR: Target app unavailable: \(rule.bundleID)")
                throw PatchPackageError.targetAppUnavailable(rule.bundleID)
            }
            do {
                try PatchTransaction.setRuleState(isOn, rule: rule, containerRoot: root)
                log("SUCCESS: \(isOn ? "Enabled" : "Disabled"): \(rule.relativePath)")
            } catch {
                log("ERROR: \(error.localizedDescription)")
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
                log("ERROR: Cannot resolve container: \(bundleID)")
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
