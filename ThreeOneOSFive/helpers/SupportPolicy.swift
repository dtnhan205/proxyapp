import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS15Range = "15.0–15.8.5 (experimental)"
    static let verifiedIOS16Range = "16.0–16.7.12 (experimental)"
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.x"
    static let verifiedIOS26Range = "26.0–26.6.1"

    static let verifiedIOS27Builds: [(beta: Int, build: String)] = [
        (1, "24A5355q"),
        (2, "24A5370h"),
        (3, "24A5380h"),
        (4, "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // iOS 15.x: 15.0 – 15.8.5 (experimental — offsets partially verified)
        if major == 15 {
            guard minor >= 0, minor <= 8 else { return false }
            return minor < 8 || (minor == 8 && patch <= 5)
        }
        // iOS 16.x: 16.0 – 16.7.12 (experimental — offsets partially verified)
        if major == 16 {
            guard minor >= 0, minor <= 7 else { return false }
            return minor < 7 || (minor == 7 && patch <= 12)
        }
        // iOS 17.x: 17.0 – 17.7.x
        if major == 17 {
            guard minor >= 0, minor <= 7 else { return false }
            return true
        }
        // iOS 18.x: 18.0 – 18.7.1
        // FilzaJailedDS notes 18.7.2 – 18.7.7 as unstable.
        if major == 18 {
            if minor == 7 && patch >= 2 && patch <= 7 { return false }
            guard minor >= 0, minor <= 7 else { return false }
            return minor < 7 || (minor == 7 && patch <= 1)
        }
        // iOS 26.x: 26.0 – 26.6.1
        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 6 || (minor == 6 && patch <= 1)
        }
        // iOS 27 beta 1 – 4
        guard major == 27, minor == 0, patch == 0 else { return false }
        return iOS27BetaNumber(for: build) != nil
    }
}
