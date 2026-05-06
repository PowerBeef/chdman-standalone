import Foundation
import zlib

/// IEEE 802.3 CRC32 backed by macOS's bundled zlib (`crc32_z`).
/// zlib's CRC32 is hardware-accelerated on Apple Silicon (PMULL / CRC
/// instructions), typically 5–10× faster than the table-driven pure-Swift
/// path the queue used to ship. Bit-exact same polynomial (0xEDB88320), so
/// values match anything the rest of the app expects.
enum CRC32 {

    /// Compute CRC32 of the entire file at `url`, reading in `bufferSize`
    /// chunks. Returns nil if the file can't be opened.
    /// `cancelCheck` is polled between chunks; return true to abort.
    static func file(
        at url: URL,
        bufferSize: Int = 1 << 20,
        cancelCheck: () -> Bool = { false }
    ) -> UInt32? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // zlib's CRC32 seed is 0; calling crc32(0, nil, 0) returns the
        // canonical initial value (also 0).
        var crc: uLong = crc32(0, nil, 0)
        while true {
            if cancelCheck() { return nil }
            guard let chunk = try? handle.read(upToCount: bufferSize),
                  !chunk.isEmpty else { break }
            crc = chunk.withUnsafeBytes { raw -> uLong in
                guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return crc }
                return crc32(crc, base, uInt(chunk.count))
            }
        }
        return UInt32(truncatingIfNeeded: crc)
    }

    /// One-shot CRC32 of an in-memory buffer.
    static func data(_ data: Data) -> UInt32 {
        let crc = data.withUnsafeBytes { raw -> uLong in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return crc32(crc32(0, nil, 0), base, uInt(data.count))
        }
        return UInt32(truncatingIfNeeded: crc)
    }
}
