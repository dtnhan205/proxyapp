import Foundation

enum DevicePatchService {
    private static var exploitHasRun = false

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

    private static func ensureExploitReady() throws {
        if exploitHasRun { return }

        Task { @MainActor in
            PatchLogService.shared.info("Initializing kernel exploit...")
        }

        // Get device info for diagnostics
        let deviceInfo = "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
        Task { @MainActor in
            PatchLogService.shared.debug("Device: \(deviceInfo)")
        }

        let result = kexploit_opa334()
        if result == 0 {
            exploitHasRun = true
            Task { @MainActor in
                PatchLogService.shared.success("Kernel exploit initialized successfully")
            }

            // Verify exploit actually worked by testing grantContainerAccess
            Task { @MainActor in
                PatchLogService.shared.info("Verifying exploit functionality...")
            }
            let testPath = "/var/mobile"
            let testClean = testPath.hasSuffix("/") ? String(testPath.dropLast()) : testPath
            var testPathC = testClean.utf8CString.map { Int8($0) }
            let testHandle = bad_query(&testPathC, false, nil, false)
            if testHandle < 0 {
                Task { @MainActor in
                    PatchLogService.shared.error("Exploit initialized but sandbox escape FAILED")
                    PatchLogService.shared.error("This device/iOS version may not be supported")
                    PatchLogService.shared.info("Supported: iOS 16.0-17.7 on A12+ devices")
                }
                exploitHasRun = false
                throw PatchPackageError.applyFailed
            } else {
                bad_query_release(testHandle)
                Task { @MainActor in
                    PatchLogService.shared.success("Sandbox escape verified (handle=\(testHandle))")
                }
            }
        } else {
            Task { @MainActor in
                PatchLogService.shared.error("Kernel exploit FAILED with code: \(result)")
                PatchLogService.shared.error("This device may not be supported by the exploit")
            }
            throw PatchPackageError.applyFailed
        }
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        // Ensure exploit is ready before accessing containers
        try ensureExploitReady()

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
                    PatchLogService.shared.error("Kernel exploit may not be compatible with this iOS version")
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
