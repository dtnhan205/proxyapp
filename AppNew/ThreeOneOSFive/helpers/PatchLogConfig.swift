import Foundation
import os.log

/// Global logging configuration for 3105 app
/// Set PATCH_DISABLE_LOGGING = true to strip all logs in production builds
enum PatchLogConfig {
    /// Compile-time flag to completely disable logging
    /// bật tắt log
    /// - false: bật log
    /// - true: tắt log
    static let loggingDisabled: Bool = false

    /// Log subsystem identifier for os_log
    static let subsystem = "com.threeoneos.five"

    /// Enable verbose debug logging (only works when loggingDisabled = false)
    /// Can be toggled at runtime
    static var verboseEnabled: Bool = true
}

/// Conditional logging that compiles away in release builds
/// Usage: Use the free function `patchLog()` instead of direct print statements
struct PatchLogger {
    private static let logger = Logger(subsystem: PatchLogConfig.subsystem, category: "patch")

    /// Core log function - compiles away when loggingDisabled = true
    @inline(__always)
    static func log(_ message: String, level: OSLogType = .default) {
        #if PATCH_DISABLE_LOGGING
        // Logs completely stripped in release
        #else
        if PatchLogConfig.loggingDisabled { return }
        logger.log(level: level, "\(message)")
        #endif
    }

    /// Debug log - only shown when verboseEnabled = true
    @inline(__always)
    static func debug(_ message: String) {
        #if PATCH_DISABLE_LOGGING
        // No-op
        #else
        if PatchLogConfig.loggingDisabled { return }
        if PatchLogConfig.verboseEnabled {
            logger.debug("\(message)")
        }
        #endif
    }

    /// Info log
    @inline(__always)
    static func info(_ message: String) {
        #if PATCH_DISABLE_LOGGING
        // No-op
        #else
        if PatchLogConfig.loggingDisabled { return }
        logger.info("\(message)")
        #endif
    }

    /// Error log - always shown unless logging is completely disabled
    @inline(__always)
    static func error(_ message: String) {
        #if PATCH_DISABLE_LOGGING
        // No-op
        #else
        if PatchLogConfig.loggingDisabled { return }
        logger.error("\(message)")
        #endif
    }
}

// MARK: - Convenience Global Functions
/// Global log function that respects compile-time and runtime settings
@inline(__always)
func patchLog(_ message: String) {
    PatchLogger.log(message)
}

@inline(__always)
func patchLogDebug(_ message: String) {
    PatchLogger.debug(message)
}

@inline(__always)
func patchLogInfo(_ message: String) {
    PatchLogger.info(message)
}

@inline(__always)
func patchLogError(_ message: String) {
    PatchLogger.error(message)
}
