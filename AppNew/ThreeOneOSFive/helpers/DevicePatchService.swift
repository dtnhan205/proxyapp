import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
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
        try withResolvedContainers(bundleIDs: [rule.bundleID]) { roots in
            guard let root = roots[rule.bundleID] else {
                throw PatchPackageError.targetAppUnavailable(rule.bundleID)
            }
            try PatchTransaction.setRuleState(isOn, rule: rule, containerRoot: root)
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
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
