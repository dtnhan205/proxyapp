import Foundation

enum DevicePatchService {
    private static var exploitHasRun = false
    private static var kernelRwValid = false

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
        if exploitHasRun && kernelRwValid { return }

        Task { @MainActor in
            PatchLogService.shared.info("=== STAGE 1/2: kernel r/w ===")
            PatchLogService.shared.info("Initializing kernel exploit...")
        }

        let kret = kexploit_opa334()
        if kret != 0 {
            Task { @MainActor in
                PatchLogService.shared.error("Kernel exploit FAILED with code: \(kret)")
                PatchLogService.shared.error("This device may not be supported by the exploit")
            }
            throw PatchPackageError.applyFailed
        }
        Task { @MainActor in
            PatchLogService.shared.success("Kernel exploit OK - kernel r/w established")
        }

        // Validate kernel r/w by reading our own proc struct
        let selfProc = proc_self()
        if selfProc == 0 {
            Task { @MainActor in
                PatchLogService.shared.error("Kernel r/w validation FAILED - proc_self() returned 0")
            }
            throw PatchPackageError.applyFailed
        }
        kernelRwValid = true
        Task { @MainActor in
            PatchLogService.shared.info("Kernel r/w validated - proc_self=0x\(String(selfProc, radix: 16))")
        }

        // iOS < 26: kernel r/w alone is sufficient
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.majorVersion < 26 {
            Task { @MainActor in
                PatchLogService.shared.info("iOS \(v.majorVersion) detected - kernel r/w sufficient (no sandbox escape needed)")
                PatchLogService.shared.success("=== EXPLOIT COMPLETE ===")
            }
            exploitHasRun = true
            return
        }

        // iOS 26+: need sandbox escape for file access
        Task { @MainActor in
            PatchLogService.shared.info("=== STAGE 2/2: sandbox escape (iOS \(v.majorVersion)) ===")
        }

        let sbxRet = sandbox_escape(selfProc)
        
        if sbxRet == 0 && hasSandboxAccess() {
            Task { @MainActor in
                PatchLogService.shared.success("Sandbox escape OK - full R+W filesystem")
                PatchLogService.shared.success("=== EXPLOIT COMPLETE ===")
            }
            exploitHasRun = true
            return
        }

        Task { @MainActor in
            PatchLogService.shared.error("Sandbox escape FAILED code=\(sbxRet)")
            PatchLogService.shared.error("iOS \(v.majorVersion) requires sandbox escape but exploit failed")
        }
        throw PatchPackageError.applyFailed
    }
    
    private static func hasSandboxAccess() -> Bool {
        sandbox_access_is_active() == 1
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
