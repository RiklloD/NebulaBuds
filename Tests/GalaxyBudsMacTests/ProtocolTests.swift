import Testing
@testable import GalaxyBudsMac

/// Sanitized frames captured from a real Galaxy Buds4 Pro (SM-R640, FW R640XXU0AZD2).
struct ProtocolTests {
    static func bytes(_ s: String) -> [UInt8] { s.split(separator: " ").map { UInt8($0, radix: 16)! } }

    static let extStatus = bytes("04 0D 64 64 01 01 11 00 00 06 FF 22 00 00 67 01 67 01 05 00 04 DD 00 02 04 10 00 00 00 00 11 02 00 01 00 01 00 00 00 01 00 00 00 00 00 00 01 00 01 01 00 00 00 01 01 01 00 00 00 00 00 01")

    @Test func encodesKnownFrames() {
        #expect(SppFrame(id: 0x26, payload: []).encoded() == Self.bytes("FD 03 00 26 A4 44 DD"))
        #expect(SppFrame(id: 0x78, payload: [1]).encoded() == Self.bytes("FD 04 00 78 01 D1 91 DD"))
        #expect(SppFrame(id: 0x88, payload: [1, 1, 0x22]).encoded() == Self.bytes("FD 06 00 88 01 01 22 DA 58 DD"))
    }

    @Test func parsesSplitStreamAndResyncs() {
        var parser = SppFrameParser()
        let ack = Self.bytes("FD 05 50 42 78 01") // header 0x5005: seq 1 + response flag
        let crc = CRC16.xmodem([0x42, 0x78, 0x01])
        let tail: [UInt8] = [UInt8(crc & 0xFF), UInt8(crc >> 8), 0xDD]
        #expect(parser.feed([0x00, 0x13] + ack).isEmpty)
        let frames = parser.feed(tail + SppFrame(id: 0x77, payload: [2]).encoded())
        #expect(frames.count == 2)
        #expect(frames[0].id == 0x42 && frames[0].payload == [0x78, 0x01])
        #expect(frames[0].isResponse && frames[0].sequence == 1)
        #expect(frames[1].id == 0x77)
    }

    @Test func rejectsBadCrc() {
        var parser = SppFrameParser()
        var f = SppFrame(id: 0x77, payload: [2]).encoded()
        f[5] ^= 0xFF
        #expect(parser.feed(f).isEmpty)
    }

    @Test func decodesExtendedStatus() {
        let s = ExtendedStatus(Self.extStatus)
        #expect(s.revision == 4)
        #expect(s.batteryL == 100 && s.batteryR == 100)
        #expect(s.placementL == .wearing && s.placementR == .wearing)
        #expect(s.eq == .custom)
        #expect(s.touchLock.enabled && s.touchLock.singleTap && s.touchLock.touchAndHoldCall)
        #expect(s.touchL == .noiseControl && s.touchR == .noiseControl)
        #expect(s.noiseControl == .off)
        #expect(s.colorName == "Black")
        #expect(s.seamlessConnection)
        #expect(s.cycleL == [.anc, .off, .ambient])
        #expect(s.ambientVolume == 2)
        #expect(s.stereoBalance == 16)
        #expect(s.sidetone && s.spatialAudio && s.callPathControl)
        #expect(!s.autoPauseResume)
        #expect(s.unknownTail.count == 5)
    }

    @Test func decodesEqualizerTable() {
        let t = EqualizerTable(Self.bytes("06 09 05 05 04 01 00 00 00 00 00 01 03 04 02 00 00 00 FD FB 02 03 03 00 FF 01 03 05 05 FB FD FF FF 00 03 02 00 00 FF FF 00 00 01 01 03 05 05 02 03 03 00 FF 01 00 02 02"))
        #expect(t.activePreset == 6)
        #expect(t.curves.count == 6)
        #expect(t.curves[0] == [5, 5, 4, 1, 0, 0, 0, 0, 0])
        #expect(t.curves[1].suffix(2) == [-3, -5])
        #expect(t.custom == [2, 3, 3, 0, -1, 1, 0, 2, 2])
    }

    // Device addresses replaced with locally administered test addresses.
    @Test func decodesDebugData() {
        let p = Self.bytes("00 02 52 36 34 30 58 58 55 30 41 5A 44 32 00 00 00 00 00 00 00 00 2E 02 00 00 00 00 01 02 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 34 01 33 01 64 00 00 00 00 00 64 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
        let d = DebugData(p)
        #expect(d.firmware == "R640XXU0AZD2")
        #expect(d.localAddress == "02:00:00:00:00:01")
        #expect(d.temperatureL == 30.8 && d.temperatureR == 30.7)
        #expect(d.socL == 100 && d.socR == 100)
        #expect(d.voltageL == nil)
    }

    @Test func decodesHeadPose() throws {
        let pose = try #require(HeadPose(Self.bytes("20 AF 1E 43 E8 87 04 00 00 F2 39 FD FF")))
        #expect(abs(pose.quaternion.length - 1) < 0.001)
    }
}
