import Foundation

/// Samsung "SPP new" framing used by Galaxy Buds+ and later (verified on Buds4 Pro, FW R640XXU0AZD2).
///
///     FD | hdr_lo hdr_hi | id | payload… | crc_lo crc_hi | DD
///
/// Header (little endian u16):
///   bits 0-9   size = 1 (id) + payload + 2 (crc)
///   bit 10/11  unknown flags (seen on some bud-originated frames)
///   bit 12     set on frames that answer a request
///   bit 13     fragment
///   bits 14-15 rolling 2-bit sequence counter (bud → host only)
/// CRC is CRC-16/XMODEM (poly 0x1021, init 0) over id + payload.
struct SppFrame: Equatable {
    static let som: UInt8 = 0xFD
    static let eom: UInt8 = 0xDD

    var id: UInt8
    var payload: [UInt8]
    var header: UInt16 = 0

    var isResponse: Bool { header & 0x1000 != 0 }
    var isFragment: Bool { header & 0x2000 != 0 }
    var sequence: Int { Int(header >> 14) }

    func encoded() -> [UInt8] {
        let body = [id] + payload
        let size = UInt16(body.count + 2)
        let crc = CRC16.xmodem(body)
        return [Self.som, UInt8(size & 0xFF), UInt8(size >> 8)] + body
            + [UInt8(crc & 0xFF), UInt8(crc >> 8), Self.eom]
    }
}

enum CRC16 {
    static func xmodem<S: Sequence>(_ bytes: S) -> UInt16 where S.Element == UInt8 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }
}

/// Reassembles frames from an RFCOMM byte stream. Resyncs on the next SOM after garbage or a bad CRC.
struct SppFrameParser {
    private var buffer: [UInt8] = []
    private(set) var droppedBytes = 0

    mutating func feed(_ bytes: [UInt8]) -> [SppFrame] {
        buffer += bytes
        var frames: [SppFrame] = []
        while true {
            guard let start = buffer.firstIndex(of: SppFrame.som) else {
                droppedBytes += buffer.count
                buffer.removeAll()
                break
            }
            if start > 0 {
                droppedBytes += start
                buffer.removeFirst(start)
            }
            guard buffer.count >= 3 else { break }
            let header = UInt16(buffer[1]) | UInt16(buffer[2]) << 8
            let size = Int(header & 0x3FF)
            let total = 3 + size + 1
            guard size >= 3 else { dropOne(); continue }
            guard buffer.count >= total else { break }

            let body = Array(buffer[3..<(3 + size - 2)])
            let crc = UInt16(buffer[3 + size - 2]) | UInt16(buffer[3 + size - 1]) << 8
            if buffer[total - 1] == SppFrame.eom, CRC16.xmodem(body) == crc {
                frames.append(SppFrame(id: body[0], payload: Array(body.dropFirst()), header: header))
                buffer.removeFirst(total)
            } else {
                dropOne()
            }
        }
        return frames
    }

    private mutating func dropOne() {
        droppedBytes += 1
        buffer.removeFirst()
    }
}

extension Array where Element == UInt8 {
    var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }

    /// ASCII string up to the first NUL.
    func cString(_ range: Range<Int>) -> String {
        guard range.lowerBound < count else { return "" }
        let slice = self[range.lowerBound..<Swift.min(range.upperBound, count)]
        return String(decoding: slice.prefix { $0 != 0 }, as: UTF8.self)
    }

    func u8(_ i: Int) -> UInt8 { i < count ? self[i] : 0 }
    func bool(_ i: Int) -> Bool { u8(i) == 1 }
    func i16le(_ i: Int) -> Int16 { Int16(bitPattern: UInt16(u8(i)) | UInt16(u8(i + 1)) << 8) }
    func u16le(_ i: Int) -> UInt16 { UInt16(u8(i)) | UInt16(u8(i + 1)) << 8 }
    func u64be(_ i: Int) -> UInt64 { (0..<8).reduce(0) { $0 << 8 | UInt64(u8(i + $1)) } }

    func mac(_ i: Int) -> String {
        (0..<6).map { String(format: "%02X", u8(i + $0)) }.joined(separator: ":")
    }
}
