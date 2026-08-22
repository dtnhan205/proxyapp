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
            ("tabHome", [0xF7, 0x74, 0xE0, 0x03, 0x66, 0xBE, 0xD0, 0xED, 0xD2, 0xD0, 0x70, 0x7D, 0x23], [0xA7, 0x06, 0x8F, 0x7B, 0x1F, 0xE8, 0xB9, 0x9D, 0x84, 0xBE, 0x50, 0x2B, 0x11])
            ("tabFiles", [0xD0, 0x73, 0x77, 0x0F, 0xD9, 0xF5, 0x7E, 0xB1], [0x96, 0x1A, 0x1B, 0x6A, 0xAA])
            ("tabPatches", [0x0B, 0xE9, 0xDB, 0x70, 0xBE, 0x56, 0xC4, 0x7E], [0x5B, 0x88, 0xAF, 0x13, 0xD6, 0x33, 0xB7])
            ("tabSettings", [0xC7, 0x8B, 0xD8, 0xEC, 0x2F, 0xE6, 0x0C, 0xA5], [0x94, 0xEE, 0xAC, 0x98, 0x46, 0x88, 0x6B, 0xD6])
            ("tabWallpapers", [0xAC, 0x73, 0x3D, 0x26, 0x07, 0x18, 0xD9, 0x70, 0xC4, 0x3F], [0xFB, 0x12, 0x51, 0x4A, 0x77, 0x79, 0xA9, 0x15, 0xB6, 0x4C])
            ]
        ),
        LocaleBlock(
            locale: "vi",
            entries: [
            ("tabHome", [0x90, 0x8B, 0x92, 0xD1, 0x88, 0xBD, 0xF6, 0x00, 0x76, 0xFC, 0x09, 0x3F, 0xB5], [0xC0, 0xF9, 0xFD, 0xA9, 0xF1, 0xEB, 0x9F, 0x70, 0x20, 0x92, 0x29, 0x69, 0x87])
            ("tabFiles", [0x0C, 0x64, 0xBC, 0x8B, 0x77, 0xA2, 0xA8, 0xA0], [0x58, 0x85, 0x07, 0x0C, 0x07])
            ("tabPatches", [0x04, 0x1D, 0xD8, 0x0B, 0xC6, 0xD3, 0x75, 0x76], [0x54, 0x7C, 0xAC, 0x68, 0xAE])
            ("tabSettings", [0x99, 0xB1, 0x7D, 0xE9, 0xE2, 0x3D, 0x40, 0x79, 0xDF, 0x32, 0xCC], [0xDA, 0x72, 0xDD, 0x80, 0xC2, 0xF9, 0xD1, 0x98, 0x65, 0x85, 0xB8])
            ("tabWallpapers", [0x5B, 0x47, 0x37, 0xDA, 0xE5, 0xB5, 0x6E, 0xF6, 0x8B, 0x98, 0xFF], [0x13, 0x84, 0x9B, 0xB4, 0x8D, 0x95, 0x00, 0x17, 0x30, 0x19, 0x91])
            ]
        ),
        LocaleBlock(
            locale: "zhHans",
            entries: [
            ("tabHome", [0x2F, 0xD3, 0xDC, 0x8F, 0x06, 0xEA, 0xEF, 0x2B, 0x58, 0x30, 0x7C, 0xB0, 0x30, 0x3C, 0x40, 0x88, 0x2F], [0x7F, 0xA1, 0xB3, 0xF7, 0x7F, 0xBC, 0x86, 0x5B, 0x0E, 0x5E, 0x5C, 0xE6, 0x02, 0x1C, 0x04, 0xDB, 0x78])
            ("tabFiles", [0x27, 0x45, 0xDA, 0xC8, 0x9A, 0x0D, 0xB9, 0xAD], [0xC1, 0xD3, 0x5D, 0x2C, 0x21, 0xBB])
            ("tabPatches", [0x43, 0x76, 0x07, 0x0D, 0x84, 0xB9, 0x70, 0x25], [0xAB, 0xD7, 0xA2, 0xE9, 0x3C, 0x38])
            ("tabSettings", [0xA5, 0x4D, 0x05, 0xA9, 0x19, 0xC6, 0xDE, 0xE1], [0x4D, 0xE3, 0xBB, 0x4E, 0xA4, 0x68])
            ("tabWallpapers", [0xF3, 0xD0, 0x1F, 0xD7, 0x8B, 0x36, 0xEF, 0x42], [0x16, 0x73, 0x9E, 0x30, 0x31, 0x8E])
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
