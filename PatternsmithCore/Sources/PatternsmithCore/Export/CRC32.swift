import Foundation

/// Standard CRC-32 (IEEE 802.3, polynomial `0xEDB88320`), the variant used by
/// zlib/PNG/gzip.
///
/// - Important: The `.mtp`/`.mt` format ends with a 4-byte CRC, but the
///   official `tracker-lib` writer stores `0` and does **not** recompute it.
///   Whether the hardware requires a valid CRC — and exactly which byte range
///   it covers — is an open question that must be confirmed on a real device.
///   This utility is provided so the exporter is ready once that is known; it
///   is not used by default.
public enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    /// Computes the CRC-32 of the given bytes.
    public static func checksum<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
