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
            ("tabHome", [0x54, 0x3A, 0x14, 0xCD, 0x00, 0x1C, 0x31, 0x17, 0xA7, 0x49, 0xD9, 0x60, 0x98], [0x04, 0x48, 0x7B, 0xB5, 0x79, 0x4A, 0x58, 0x67, 0xF1, 0x27, 0xF9, 0x36, 0xAA]),
            ("tabFiles", [0xE3, 0xD9, 0x04, 0xD0, 0xE3, 0x01, 0x68, 0x59], [0xA5, 0xB0, 0x68, 0xB5, 0x90]),
            ("tabPatches", [0x2C, 0xD2, 0x19, 0xD7, 0x90, 0x2F, 0xC3, 0x4F], [0x7C, 0xB3, 0x6D, 0xB4, 0xF8, 0x4A, 0xB0]),
            ("tabSettings", [0x28, 0xF4, 0xDD, 0xA0, 0x34, 0x8D, 0x6D, 0x0B], [0x7B, 0x91, 0xA9, 0xD4, 0x5D, 0xE3, 0x0A, 0x78]),
            ("tabWallpapers", [0xC3, 0x7F, 0xC9, 0xF5, 0x1E, 0x82, 0x10, 0x0A, 0x1B, 0x7F], [0x94, 0x1E, 0xA5, 0x99, 0x6E, 0xE3, 0x60, 0x6F, 0x69, 0x0C]),
            ]
        ),
        LocaleBlock(
            locale: "vi",
            entries: [
            ("tabHome", [0x23, 0xC9, 0xE3, 0x17, 0x3B, 0x08, 0x28, 0x64, 0x68, 0x00, 0xBB, 0x5E, 0x93], [0x73, 0xBB, 0x8C, 0x6F, 0x42, 0x5E, 0x41, 0x14, 0x3E, 0x6E, 0x9B, 0x08, 0xA1]),
            ("tabFiles", [0xC1, 0x12, 0xD3, 0xE1, 0x34, 0x56, 0x77, 0xC7], [0x95, 0xF3, 0x68, 0x66, 0x44]),
            ("tabPatches", [0xC7, 0xE1, 0xF9, 0x24, 0x5A, 0xB4, 0xF1, 0x28], [0x97, 0x80, 0x8D, 0x47, 0x32]),
            ("tabSettings", [0x92, 0xE8, 0x69, 0x01, 0xED, 0x3A, 0x27, 0xFD, 0xBD, 0x5D, 0x70], [0xD1, 0x2B, 0xC9, 0x68, 0xCD, 0xFE, 0xB6, 0x1C, 0x07, 0xEA, 0x04]),
            ("tabWallpapers", [0xDB, 0xE0, 0xBF, 0x46, 0x9A, 0xFF, 0xB0, 0x7B, 0x12, 0xE4, 0x98], [0x93, 0x23, 0x13, 0x28, 0xF2, 0xDF, 0xDE, 0x9A, 0xA9, 0x65, 0xF6]),
            ]
        ),
        LocaleBlock(
            locale: "zhHans",
            entries: [
            ("tabHome", [0x26, 0xCF, 0xB2, 0xB9, 0x46, 0xEB, 0x53, 0xBF, 0x66, 0x46, 0xFC, 0x97, 0xF6, 0x06, 0x04, 0x04, 0x37], [0x76, 0xBD, 0xDD, 0xC1, 0x3F, 0xBD, 0x3A, 0xCF, 0x30, 0x28, 0xDC, 0xC1, 0xC4, 0x26, 0x40, 0x57, 0x60]),
            ("tabFiles", [0xCE, 0xB9, 0x66, 0xDB, 0x91, 0xBD, 0x24, 0xA4], [0x28, 0x2F, 0xE1, 0x3F, 0x2A, 0x0B]),
            ("tabPatches", [0xBA, 0x9B, 0xBF, 0xA0, 0x06, 0x2C, 0x7C, 0x1A], [0x52, 0x3A, 0x1A, 0x44, 0xBE, 0xAD]),
            ("tabSettings", [0x88, 0xF7, 0xB5, 0x95, 0x00, 0x32, 0xD0, 0x77], [0x60, 0x59, 0x0B, 0x72, 0xBD, 0x9C]),
            ("tabWallpapers", [0x62, 0xFB, 0x78, 0xE8, 0x74, 0x99, 0x3E, 0x86], [0x87, 0x58, 0xF9, 0x0F, 0xCE, 0x21]),
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
