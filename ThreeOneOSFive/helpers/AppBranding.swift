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
            ("tabHome", [0x8F, 0x48, 0x1E, 0xB4, 0xCF, 0x13, 0x66, 0x63, 0xA4, 0xEC, 0x0D, 0xD9, 0x6D], [0xDF, 0x3A, 0x71, 0xCC, 0xB6, 0x45, 0x0F, 0x13, 0xF2, 0x82, 0x2D, 0x8F, 0x5F]),
            ("tabFiles", [0x00, 0xBE, 0xCD, 0xEF, 0x86, 0x28, 0xDD, 0x72], [0x46, 0xD7, 0xA1, 0x8A, 0xF5]),
            ("tabPatches", [0x53, 0xAD, 0x3A, 0x50, 0x70, 0x1A, 0x47, 0x03], [0x03, 0xCC, 0x4E, 0x33, 0x18, 0x7F, 0x34]),
            ("tabSettings", [0x66, 0x49, 0x20, 0x0E, 0x6A, 0x04, 0x25, 0x1B], [0x35, 0x2C, 0x54, 0x7A, 0x03, 0x6A, 0x42, 0x68]),
            ("tabWallpapers", [0x08, 0xE2, 0x2B, 0x31, 0x33, 0xC7, 0x66, 0xAB, 0x03, 0xC3], [0x5F, 0x83, 0x47, 0x5D, 0x43, 0xA6, 0x16, 0xCE, 0x71, 0xB0]),
            ]
        ),
        LocaleBlock(
            locale: "vi",
            entries: [
            ("tabHome", [0x1A, 0x5F, 0x92, 0xD3, 0x04, 0x6B, 0xE7, 0xDB, 0x93, 0x1A, 0x2B, 0x79, 0x7B], [0x4A, 0x2D, 0xFD, 0xAB, 0x7D, 0x3D, 0x8E, 0xAB, 0xC5, 0x74, 0x0B, 0x2F, 0x49]),
            ("tabFiles", [0x4F, 0x4D, 0xE8, 0x4E, 0x8E, 0xBA, 0xD1, 0x76], [0x1B, 0xAC, 0x53, 0xC9, 0xFE]),
            ("tabPatches", [0x1C, 0x66, 0x95, 0x0F, 0xDB, 0x27, 0x83, 0x3A], [0x4C, 0x07, 0xE1, 0x6C, 0xB3]),
            ("tabSettings", [0x52, 0xBF, 0x2E, 0x2B, 0x57, 0x51, 0x00, 0x3C, 0xBB, 0xCD, 0x96], [0x11, 0x7C, 0x8E, 0x42, 0x77, 0x95, 0x91, 0xDD, 0x01, 0x7A, 0xE2]),
            ("tabWallpapers", [0x0F, 0x38, 0x5F, 0x6B, 0xD0, 0xAD, 0x77, 0x5D, 0x2A, 0x6E, 0xDF], [0x47, 0xFB, 0xF3, 0x05, 0xB8, 0x8D, 0x19, 0xBC, 0x91, 0xEF, 0xB1]),
            ]
        ),
        LocaleBlock(
            locale: "zhHans",
            entries: [
            ("tabHome", [0x12, 0xE3, 0x68, 0x49, 0x3E, 0x4B, 0x56, 0x6D, 0x08, 0x7B, 0x5E, 0x55, 0x67, 0x3D, 0x15, 0xAB, 0xD0], [0x42, 0x91, 0x07, 0x31, 0x47, 0x1D, 0x3F, 0x1D, 0x5E, 0x15, 0x7E, 0x03, 0x55, 0x1D, 0x51, 0xF8, 0x87]),
            ("tabFiles", [0x5C, 0xA1, 0xE5, 0xAB, 0x3F, 0x9A, 0xED, 0xAA], [0xBA, 0x37, 0x62, 0x4F, 0x84, 0x2C]),
            ("tabPatches", [0xB1, 0x32, 0x05, 0x99, 0xCA, 0xF8, 0x01, 0xA9], [0x59, 0x93, 0xA0, 0x7D, 0x72, 0x79]),
            ("tabSettings", [0x68, 0x8D, 0x56, 0x6D, 0x79, 0xC5, 0x80, 0xF3], [0x80, 0x23, 0xE8, 0x8A, 0xC4, 0x6B]),
            ("tabWallpapers", [0x4A, 0x01, 0x03, 0xC2, 0x97, 0x9F, 0x94, 0xA5], [0xAF, 0xA2, 0x82, 0x25, 0x2D, 0x27]),
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
