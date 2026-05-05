import Foundation

/// Pure-Swift streaming CRC32 (IEEE 802.3 polynomial 0xEDB88320).
/// Hand-rolled to avoid any system-zlib FFI surprises. ~250-300 MB/s
/// per core on Apple Silicon — fast enough that hashing a 600 MB
/// PSX track is well under 3 seconds even on a single thread.
enum CRC32 {

    private static let table: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            t[i] = c
        }
        return t
    }()

    /// Compute CRC32 of the entire file at `url`, reading in 1 MiB
    /// chunks. Returns nil if the file can't be opened.
    /// `cancelCheck` is polled between chunks; return true to abort.
    static func file(
        at url: URL,
        bufferSize: Int = 1 << 20,
        cancelCheck: () -> Bool = { false }
    ) -> UInt32? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var crc: UInt32 = 0xFFFFFFFF
        let tbl = table
        while true {
            if cancelCheck() { return nil }
            guard let chunk = try? handle.read(upToCount: bufferSize),
                  !chunk.isEmpty else { break }
            chunk.withUnsafeBytes { raw in
                guard let p = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                let count = chunk.count
                for i in 0..<count {
                    crc = tbl[Int((crc ^ UInt32(p[i])) & 0xFF)] ^ (crc >> 8)
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
