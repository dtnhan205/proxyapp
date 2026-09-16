#!/usr/bin/env python3
"""Generate AppBranding.swift from brand strings, with XOR obfuscation + hex encoding.

Mỗi string được XOR với key ngẫu nhiên rồi encode thành hex byte array.
App chỉ chứa hex byte + key trong binary — `strings` không tìm ra tên brand.

Usage:
  python3 tools/gen_branding.py                  # generate ThreeOneOSFive/helpers/AppBranding.swift
  python3 tools/gen_branding.py --print          # print Swift to stdout
  python3 tools/gen_branding.py --out-dir PATH  # write AppBranding.swift vào PATH

Build integration:
  Wire this script vào GitHub Actions workflow TRƯỚC khi xcodebuild.
  Dùng --out-dir để trỏ vào project con (vd AppNew/ThreeOneOSFive/helpers).
"""
import os
import sys
import secrets
from pathlib import Path

# Brand strings theo từng ngôn ngữ. Thêm/sửa ở đây khi muốn đổi tên hiển thị.
BRAND_STRINGS = {
    "en": {
        "tabHome":       "ProxyIPA OB55",
        "tabFiles":      "Files",
        "tabPatches":    "Patches",
        "tabSettings":   "Settings",
        "tabWallpapers": "Wallpapers",
    },
    "vi": {
        "tabHome":       "ProxyIPA OB55",
        "tabFiles":      "Tệp",
        "tabPatches":    "Patch",
        "tabSettings":   "Cài đặt",
        "tabWallpapers": "Hình nền",
    },
    "zhHans": {
        "tabHome":       "ProxyIPA OB55 DSW",
        "tabFiles":      "文件",
        "tabPatches":    "补丁",
        "tabSettings":   "设置",
        "tabWallpapers": "壁纸",
    },
}


def encode(plaintext: str, key: bytes) -> bytes:
    """XOR plaintext với key (cycling). Return ciphertext bytes."""
    pt = plaintext.encode("utf-8")
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(pt))


def fmt_bytes(b: bytes) -> str:
    """Format bytes array dạng Swift: 0x41, 0x42, ..."""
    return ", ".join(f"0x{x:02X}" for x in b)


def fmt_string_array(items):
    """Mỗi item là tuple (key_name, bytes_array_string)."""
    return ",\n            ".join(items)


def generate_key_for_locale(locale: str, total_bytes: int) -> bytes:
    """Mỗi locale một key riêng. Key length = min(32, total_bytes)."""
    key_len = max(8, min(32, total_bytes))
    return secrets.token_bytes(key_len)


def make_locale_block(locale: str, strings: dict) -> str:
    """Generate 1 block Swift code cho 1 locale. Mỗi entry là positional tuple.
    Lưu ý: phải có dấu `,` SAU mỗi tuple để Swift array literal phân tách entries.
    """
    tuple_items = []
    for name, value in strings.items():
        key = generate_key_for_locale(locale, len(value.encode("utf-8")))
        ct = encode(value, key)
        key_pretty = fmt_bytes(key)
        ct_pretty = fmt_bytes(ct)
        # Positional tuple (String, [UInt8], [UInt8]) — khớp kiểu dưới.
        # BẮT BUỘC có `,` ở cuối, nếu không Swift báo "expected ',' separator".
        tuple_items.append(f'            ("{name}", [{key_pretty}], [{ct_pretty}]),')
    return "\n".join(tuple_items)


def generate_swift() -> str:
    """Generate full Swift file content."""
    locale_blocks = []
    locales_in_order = ["en", "vi", "zhHans"]
    for locale in locales_in_order:
        block = make_locale_block(locale, BRAND_STRINGS[locale])
        locale_blocks.append(
            f'        LocaleBlock(\n            locale: "{locale}",\n            entries: [\n{block}\n            ]\n        )'
        )

    body = ",\n".join(locale_blocks)

    swift = f'''// GENERATED FILE — DO NOT EDIT BY HAND
//
// Nguồn: tools/gen_branding.py
// Build script sẽ regenerate file này mỗi lần build. Đổi brand strings
// tại BRAND_STRINGS trong gen_branding.py, KHÔNG sửa trực tiếp file này.
//
// Mục đích: tránh cracker `strings` ra binary và đổi tên app sang "FooBar"
// để rebrand. Plaintext không tồn tại trong binary, chỉ có hex byte + key.
// Runtime XOR-decode khi cần hiển thị (cached).

import Foundation

enum AppBranding {{

    /// Tham chiếu 1 entry đã XOR-encode. Positional tuple `(name, key, ct)`.
    private typealias EntryTuple = (String, [UInt8], [UInt8])

    /// Nhóm các entry của 1 locale. Init nhận mảng tuple và zip thành dictionary.
    private struct LocaleBlock {{
        let locale: String
        let entries: [String: [UInt8]]   // name → ct
        let keys:    [String: [UInt8]]   // name → key
        init(locale: String, entries: [EntryTuple]) {{
            self.locale = locale
            var ctMap: [String: [UInt8]] = [:]
            var keyMap: [String: [UInt8]] = [:]
            for (name, k, ct) in entries {{
                ctMap[name] = ct
                keyMap[name] = k
            }}
            self.entries = ctMap
            self.keys = keyMap
        }}
    }}

    /// Dữ liệu đã encode, key theo locale. Plaintext KHÔNG tồn tại trong binary.
    private static let blocks: [LocaleBlock] = [
{body}
    ]

    // MARK: - Lazy cache (chỉ decode 1 lần / locale).

    private static var cache: [String: [String: String]] = [:]

    private static func decode(key: [UInt8], ct: [UInt8]) -> String {{
        var out = [UInt8](repeating: 0, count: ct.count)
        for i in 0..<ct.count {{
            out[i] = ct[i] ^ key[i % key.count]
        }}
        return String(bytes: out, encoding: .utf8) ?? ""
    }}

    private static func decodedMap(for locale: String) -> [String: String] {{
        if let cached = cache[locale] {{ return cached }}
        guard let block = blocks.first(where: {{ $0.locale == locale }}) else {{
            // Fallback về "en" nếu locale không có (vd en-GB, zh-Hant).
            if locale != "en" {{
                return decodedMap(for: "en")
            }}
            return [:]
        }}
        var map: [String: String] = [:]
        for (name, ct) in block.entries {{
            guard let key = block.keys[name] else {{ continue }}
            map[name] = decode(key: key, ct: ct)
        }}
        cache[locale] = map
        return map
    }}

    // MARK: - Public API

    /// Trả về brand string đã decode cho locale hiện tại.
    /// - Parameters:
    ///   - name: tên entry, ví dụ "tabHome", "tabFiles", "tabSettings".
    ///   - locale: "en", "vi", hoặc "zh-Hans" (map nội bộ sang key).
    static func string(_ name: String, locale: String) -> String {{
        let key = canonicalLocale(locale)
        return decodedMap(for: key)[name] ?? ""
    }}

    /// Map locale code sang key trong `blocks`. iOS trả "zh-Hans" → "zhHans".
    private static func canonicalLocale(_ locale: String) -> String {{
        switch locale {{
        case "zh-Hans", "zhHans": return "zhHans"
        case "vi":                return "vi"
        case "en":                return "en"
        default:                  return "en"
        }}
    }}
}}
'''
    return swift


def main():
    # Mặc định vẫn ghi vào ThreeOneOSFive/helpers/AppBranding.swift ở root
    # (backwards-compat). Có thể override bằng --out-dir để build các project
    # con khác (vd AppNew/ThreeOneOSFive/helpers/AppBranding.swift).
    default_out = Path(__file__).resolve().parent.parent / "ThreeOneOSFive" / "helpers"
    out_dir = default_out
    for i, arg in enumerate(sys.argv):
        if arg == "--out-dir" and i + 1 < len(sys.argv):
            out_dir = Path(sys.argv[i + 1])
            break
    out_path = out_dir / "AppBranding.swift"

    content = generate_swift()

    if "--print" in sys.argv:
        print(content)
        return

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content, encoding="utf-8")
    print(f"[gen_branding] wrote {out_path} ({len(content)} bytes)")


if __name__ == "__main__":
    main()
