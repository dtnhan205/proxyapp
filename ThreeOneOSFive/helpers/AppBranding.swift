// GENERATED FILE — DO NOT EDIT BY HAND
//
// Nguồn: tools/gen_branding.py
// Build script sẽ regenerate file này mỗi lần build. Đổi brand strings
// tại BRAND_STRINGS trong gen_branding.py, KHÔNG sửa trực tiếp file này.
//
// Mục đích: tránh cracker `strings` ra binary và đổi tên app sang "FooBar"
// để rebrand. Plaintext không tồn tại trong binary, chỉ có hex byte + key.
// Runtime XOR-decode khi cần hiển thị (cached).

import Foundation

enum AppBranding {

    /// Tham chiếu 1 entry đã XOR-encode. Positional tuple `(name, key, ct)`.
    private typealias EntryTuple = (String, [UInt8], [UInt8])

    /// Nhóm các entry của 1 locale. Init nhận mảng tuple và zip thành dictionary.
    private struct LocaleBlock {
        let locale: String
        let entries: [String: [UInt8]]   // name → ct
        let keys:    [String: [UInt8]]   // name → key
        init(locale: String, entries: [EntryTuple]) {
            self.locale = locale
            var ctMap: [String: [UInt8]] = [:]
            var keyMap: [String: [UInt8]] = [:]
            for (name, k, ct) in entries {
                ctMap[name] = ct
                keyMap[name] = k
            }
            self.entries = ctMap
            self.keys = keyMap
        }
    }

    /// Dữ liệu đã encode, key theo locale. Plaintext KHÔNG tồn tại trong binary.
    private static let blocks: [LocaleBlock] = [
        LocaleBlock(
            locale: "en",
            entries: [
            ("tabHome", [0xED, 0x81, 0xE8, 0xAC, 0xBE, 0xBD, 0xEE, 0x1C, 0x09, 0xDD, 0x29, 0xE4, 0x56], [0xBD, 0xF3, 0x87, 0xD4, 0xC7, 0xEB, 0x87, 0x6C, 0x5F, 0xB3, 0x09, 0xB2, 0x64]),
            ("tabFiles", [0x4D, 0x69, 0x87, 0xE8, 0xBB, 0xDF, 0xDA, 0x57], [0x0B, 0x00, 0xEB, 0x8D, 0xC8]),
            ("tabPatches", [0x8C, 0x2B, 0x19, 0x62, 0xC4, 0x11, 0xE6, 0x92], [0xDC, 0x4A, 0x6D, 0x01, 0xAC, 0x74, 0x95]),
            ("tabSettings", [0x37, 0xA3, 0xAB, 0xFC, 0x76, 0x5B, 0x67, 0x79], [0x64, 0xC6, 0xDF, 0x88, 0x1F, 0x35, 0x00, 0x0A]),
            ("tabWallpapers", [0xE3, 0xD4, 0x03, 0xA1, 0x2A, 0x31, 0x6F, 0xEC, 0xA0, 0x7E], [0xB4, 0xB5, 0x6F, 0xCD, 0x5A, 0x50, 0x1F, 0x89, 0xD2, 0x0D]),
            ]
        ),
        LocaleBlock(
            locale: "vi",
            entries: [
            ("tabHome", [0xE5, 0xC5, 0x11, 0xA5, 0xFC, 0x17, 0x62, 0xEA, 0x85, 0xF3, 0x63, 0xF5, 0x5D], [0xB5, 0xB7, 0x7E, 0xDD, 0x85, 0x41, 0x0B, 0x9A, 0xD3, 0x9D, 0x43, 0xA3, 0x6F]),
            ("tabFiles", [0xAC, 0x78, 0xD0, 0xBD, 0x9F, 0x09, 0x11, 0xE1], [0xF8, 0x99, 0x6B, 0x3A, 0xEF]),
            ("tabPatches", [0x01, 0xAC, 0x73, 0x86, 0xFC, 0x88, 0xCE, 0x4A], [0x51, 0xCD, 0x07, 0xE5, 0x94]),
            ("tabSettings", [0xF3, 0x15, 0xB9, 0x45, 0x80, 0x13, 0x79, 0x45, 0xC9, 0xFE, 0x1B], [0xB0, 0xD6, 0x19, 0x2C, 0xA0, 0xD7, 0xE8, 0xA4, 0x73, 0x49, 0x6F]),
            ("tabWallpapers", [0x23, 0x96, 0xC5, 0x43, 0x2D, 0x3E, 0x85, 0x25, 0x9C, 0xAB, 0xFC], [0x6B, 0x55, 0x69, 0x2D, 0x45, 0x1E, 0xEB, 0xC4, 0x27, 0x2A, 0x92]),
            ]
        ),
        LocaleBlock(
            locale: "zhHans",
            entries: [
            ("tabHome", [0x86, 0x29, 0x04, 0xD1, 0xAF, 0xA3, 0x21, 0xA2, 0xDD, 0x14, 0xC3, 0x8A, 0xAD, 0x29, 0x9C, 0xA9, 0xE0], [0xD6, 0x5B, 0x6B, 0xA9, 0xD6, 0xF5, 0x48, 0xD2, 0x8B, 0x7A, 0xE3, 0xDC, 0x9F, 0x09, 0xD8, 0xFA, 0xB7]),
            ("tabFiles", [0xB7, 0x81, 0xB1, 0xFC, 0x6E, 0x86, 0xBA, 0xAD], [0x51, 0x17, 0x36, 0x18, 0xD5, 0x30]),
            ("tabPatches", [0x99, 0xD0, 0xD6, 0x37, 0x3B, 0x24, 0x99, 0xD5], [0x71, 0x71, 0x73, 0xD3, 0x83, 0xA5]),
            ("tabSettings", [0x0C, 0x04, 0xC1, 0xB0, 0x27, 0xAD, 0xF9, 0xB0], [0xE4, 0xAA, 0x7F, 0x57, 0x9A, 0x03]),
            ("tabWallpapers", [0xF8, 0xFE, 0xC5, 0xAB, 0x54, 0xAB, 0x73, 0x5D], [0x1D, 0x5D, 0x44, 0x4C, 0xEE, 0x13]),
            ]
        )
    ]

    // MARK: - Lazy cache (chỉ decode 1 lần / locale).

    private static var cache: [String: [String: String]] = [:]

    private static func decode(key: [UInt8], ct: [UInt8]) -> String {
        var out = [UInt8](repeating: 0, count: ct.count)
        for i in 0..<ct.count {
            out[i] = ct[i] ^ key[i % key.count]
        }
        return String(bytes: out, encoding: .utf8) ?? ""
    }

    private static func decodedMap(for locale: String) -> [String: String] {
        if let cached = cache[locale] { return cached }
        guard let block = blocks.first(where: { $0.locale == locale }) else {
            // Fallback về "en" nếu locale không có (vd en-GB, zh-Hant).
            if locale != "en" {
                return decodedMap(for: "en")
            }
            return [:]
        }
        var map: [String: String] = [:]
        for (name, ct) in block.entries {
            guard let key = block.keys[name] else { continue }
            map[name] = decode(key: key, ct: ct)
        }
        cache[locale] = map
        return map
    }

    // MARK: - Public API

    /// Trả về brand string đã decode cho locale hiện tại.
    /// - Parameters:
    ///   - name: tên entry, ví dụ "tabHome", "tabFiles", "tabSettings".
    ///   - locale: "en", "vi", hoặc "zh-Hans" (map nội bộ sang key).
    static func string(_ name: String, locale: String) -> String {
        let key = canonicalLocale(locale)
        return decodedMap(for: key)[name] ?? ""
    }

    /// Map locale code sang key trong `blocks`. iOS trả "zh-Hans" → "zhHans".
    private static func canonicalLocale(_ locale: String) -> String {
        switch locale {
        case "zh-Hans", "zhHans": return "zhHans"
        case "vi":                return "vi"
        case "en":                return "en"
        default:                  return "en"
        }
    }
}
