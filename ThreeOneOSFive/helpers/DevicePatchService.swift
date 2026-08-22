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

    static func setRuleState(_ isOn: Bool, rule: PatchRule) throws {
        Task { @MainActor in
            PatchLogService.shared.clear()
            PatchLogService.shared.isVisible = true
            PatchLogService.shared.info("=== PATCH PROCESS STARTED ===")
            PatchLogService.shared.info("Bundle: \(rule.bundleID)")
            PatchLogService.shared.info("Rule: \(rule.relativePath)")
            PatchLogService.shared.info("Action: \(isOn ? "ENABLE" : "DISABLE")")
        }

        do {
            try withResolvedContainers(bundleIDs: [rule.bundleID]) { roots in
                guard let root = roots[rule.bundleID] else {
                    Task { @MainActor in
                        PatchLogService.shared.error("Container not found for \(rule.bundleID)")
                    }
                    throw PatchPackageError.targetAppUnavailable(rule.bundleID)
                }

                Task { @MainActor in
                    PatchLogService.shared.success("Container resolved: \(root.path)")
                }

                try PatchTransaction.setRuleState(isOn, rule: rule, containerRoot: root)
            }

            Task { @MainActor in
                PatchLogService.shared.success("=== PATCH \(isOn ? "ENABLED" : "DISABLED") SUCCESS ===")
            }
        } catch {
            Task { @MainActor in
                PatchLogService.shared.error("PATCH FAILED: \(error.localizedDescription)")
            }
            throw error
        }
    }

    static func currentRuleState(for rule: PatchRule) -> Bool? {
        try? withResolvedContainers(bundleIDs: [rule.bundleID]) { roots in
            guard let root = roots[rule.bundleID] else { return nil }
            return PatchTransaction.currentRuleState(rule: rule, containerRoot: root)
        }
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        var seen = Set<String>()
        return project.rules.compactMap { seen.insert($0.bundleID).inserted ? $0.bundleID : nil }
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]
        var handles: [Int64] = []
        defer { handles.forEach(bad_query_release) }

        for bundleID in bundleIDs {
            Task { @MainActor in
                PatchLogService.shared.info("Resolving container: \(bundleID)")
            }

            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
                Task { @MainActor in
                    PatchLogService.shared.error("MCMActivateContainerPath failed for \(bundleID)")
                }
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }

            Task { @MainActor in
                PatchLogService.shared.debug("Path resolved: \(path)")
            }

            guard ContainerStore.isApplicationContainerPath(path) else {
                Task { @MainActor in
                    PatchLogService.shared.error("Path validation failed: not an application container")
                }
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }

            Task { @MainActor in
                PatchLogService.shared.info("Acquiring traversal grant...")
            }

            let handle = ContainerStore.grantContainerAccess(path)
            if handle < 0 {
                Task { @MainActor in
                    PatchLogService.shared.error("bad_query() FAILED, handle=\(handle)")
                    PatchLogService.shared.error("This usually means the kernel exploit didn't run successfully!")
                    PatchLogService.shared.info("Try running the exploit first from the Dashboard")
                }
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }

            Task { @MainActor in
                PatchLogService.shared.success("Traversal grant acquired, handle=\(handle)")
            }

            handles.append(handle)
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
