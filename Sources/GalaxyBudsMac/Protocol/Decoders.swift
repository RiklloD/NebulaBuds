import Foundation
import simd

enum NoiseControlMode: UInt8, CaseIterable, Identifiable {
    case off = 0, anc = 1, ambient = 2, adaptive = 3
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .off: "Off"
        case .anc: "Noise Cancelling"
        case .ambient: "Ambient"
        case .adaptive: "Adaptive"
        }
    }
    var symbol: String {
        switch self {
        case .off: "speaker.wave.1"
        case .anc: "ear.trianglebadge.exclamationmark"
        case .ambient: "ear.and.waveform"
        case .adaptive: "waveform.badge.magnifyingglass"
        }
    }
}

enum Placement: UInt8 {
    case disconnected = 0, wearing = 1, idle = 2, inCase = 3, closedCase = 4
    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .wearing: "In ear"
        case .idle: "Out of ear"
        case .inCase: "In case"
        case .closedCase: "Case closed"
        }
    }
}

enum TouchAction: UInt8, CaseIterable, Identifiable {
    case voiceAssistant = 1, noiseControl = 2, volume = 3, spotify = 4
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .voiceAssistant: "Voice assistant"
        case .noiseControl: "Switch noise controls"
        case .volume: "Volume"
        case .spotify: "Spotify"
        }
    }
}

enum EqPreset: UInt8, CaseIterable, Identifiable {
    case off = 0, bassBoost = 1, soft = 2, dynamic = 3, clear = 4, trebleBoost = 5, custom = 6
    var id: UInt8 { rawValue }
    var label: String {
        switch self {
        case .off: "Off"
        case .bassBoost: "Bass boost"
        case .soft: "Soft"
        case .dynamic: "Dynamic"
        case .clear: "Clear"
        case .trebleBoost: "Treble boost"
        case .custom: "Custom"
        }
    }
}

/// Bitmask used by the touch-and-hold noise control cycle (status byte 21, command 0x79).
struct NoiseCycle: OptionSet, Equatable {
    let rawValue: UInt8
    static let ambient = NoiseCycle(rawValue: 1)
    static let adaptive = NoiseCycle(rawValue: 2)
    static let off = NoiseCycle(rawValue: 4)
    static let anc = NoiseCycle(rawValue: 8)
}

/// Touch lock bitfield (status byte 10). Bit 7 set = touch controls enabled.
struct TouchLock: Equatable {
    var enabled = true
    var singleTap = true
    var doubleTap = true
    var tripleTap = true
    var touchAndHold = true
    var doubleTapCall = true
    var touchAndHoldCall = true

    init() {}
    init(byte b: UInt8) {
        touchAndHold = b & 0x01 != 0
        tripleTap = b & 0x02 != 0
        doubleTap = b & 0x04 != 0
        singleTap = b & 0x08 != 0
        doubleTapCall = b & 0x10 != 0
        touchAndHoldCall = b & 0x20 != 0
        enabled = b & 0x80 != 0
    }

    var payload: [UInt8] {
        [enabled, singleTap, doubleTap, tripleTap, touchAndHold, doubleTapCall, touchAndHoldCall].map { $0 ? 1 : 0 }
    }
}

/// EXTENDED_STATUS_UPDATED (0x61). Layout verified against a Buds4 Pro (revision 4, 62 bytes).
struct ExtendedStatus {
    var revision: UInt8 = 0
    var batteryL = 0, batteryR = 0, batteryCase = 0
    var coupled = false
    var mainIsLeft = false
    var placementL = Placement.disconnected, placementR = Placement.disconnected
    var chargingL = false, chargingR = false, chargingCase = false
    var eq = EqPreset.off
    var touchLock = TouchLock()
    var touchL = TouchAction.noiseControl, touchR = TouchAction.noiseControl
    var noiseControl = NoiseControlMode.off
    var voiceWakeUp = false
    var colorId: UInt16 = 0
    var seamlessConnection = false
    var cycleL = NoiseCycle(), cycleR = NoiseCycle()
    var speakSeamlessly = false
    var ambientVolume = 0
    var noiseReductionLevel = 0
    var stereoBalance = 16
    var detectConversations = false
    var detectConversationsDuration = 0
    var ancWithOneEarbud = false
    var customAmbientOn = false
    var customAmbientL = 0, customAmbientR = 0, customAmbientTone = 0
    var sidetone = false
    var callPathControl = false
    var spatialAudio = false
    var headTracking = false
    var extraClearCall = false
    var autoPauseResume = false
    var adaptiveVolume = false
    var sirenDetect = false
    var adaptSound = false
    var unknownTail: [UInt8] = []

    init() {}

    init(_ p: [UInt8]) {
        revision = p.u8(0)
        batteryL = Int(p.u8(2))
        batteryR = Int(p.u8(3))
        coupled = p.bool(4)
        mainIsLeft = p.u8(5) == 1
        placementL = Placement(rawValue: p.u8(6) >> 4) ?? .disconnected
        placementR = Placement(rawValue: p.u8(6) & 0x0F) ?? .disconnected
        batteryCase = Int(p.u8(7))
        eq = EqPreset(rawValue: p.u8(9)) ?? .off
        touchLock = TouchLock(byte: p.u8(10))
        touchL = TouchAction(rawValue: p.u8(11) >> 4) ?? .noiseControl
        touchR = TouchAction(rawValue: p.u8(11) & 0x0F) ?? .noiseControl
        noiseControl = NoiseControlMode(rawValue: p.u8(12)) ?? .off
        voiceWakeUp = p.bool(13)
        colorId = p.u16le(14)
        seamlessConnection = p.u8(19) == 0
        cycleL = NoiseCycle(rawValue: p.u8(21) >> 4)
        cycleR = NoiseCycle(rawValue: p.u8(21) & 0x0F)
        speakSeamlessly = p.bool(22)
        ambientVolume = Int(p.u8(23))
        noiseReductionLevel = Int(p.u8(24))
        stereoBalance = Int(p.u8(25))
        detectConversations = p.bool(26)
        detectConversationsDuration = Int(min(p.u8(27), 2))
        ancWithOneEarbud = p.bool(28)
        customAmbientOn = p.bool(29)
        customAmbientL = Int(p.u8(30) >> 4)
        customAmbientR = Int(p.u8(30) & 0x0F)
        customAmbientTone = Int(p.u8(31))
        sidetone = p.bool(33)
        callPathControl = p.u8(34) == 0
        spatialAudio = p.bool(35)
        headTracking = p.bool(41)
        let charging = p.u8(42)
        chargingL = charging & 0x10 != 0
        chargingR = charging & 0x04 != 0
        chargingCase = charging & 0x01 != 0
        extraClearCall = p.bool(43)
        autoPauseResume = p.bool(45)
        adaptiveVolume = p.bool(49)
        sirenDetect = p.bool(52)
        adaptSound = p.bool(53)
        unknownTail = p.count > 57 ? Array(p[57...]) : []
    }

    var colorName: String {
        switch colorId {
        case 359: "Black"
        case 360: "White"
        case 361: "Apricot"
        default: "#\(colorId)"
        }
    }
}

/// STATUS_UPDATED (0x60): the lightweight battery/wear push.
struct BasicStatus {
    var batteryL, batteryR, batteryCase: Int
    var placementL, placementR: Placement
    var chargingL, chargingR, chargingCase: Bool

    init(_ p: [UInt8]) {
        batteryL = Int(p.u8(1))
        batteryR = Int(p.u8(2))
        placementL = Placement(rawValue: p.u8(5) >> 4) ?? .disconnected
        placementR = Placement(rawValue: p.u8(5) & 0x0F) ?? .disconnected
        batteryCase = Int(p.u8(6))
        let c = p.u8(7)
        chargingL = c & 0x10 != 0
        chargingR = c & 0x04 != 0
        chargingCase = c & 0x01 != 0
    }
}

/// DEBUG_GET_ALL_DATA (0x26). Buds3+ layout with a 20 byte firmware string.
/// The Buds4 Pro answers twice: first with only the primary bud's sensors filled, then both.
struct DebugData {
    var hardwareRevision = ""
    var firmware = ""
    var localAddress = "", peerAddress = ""
    var temperatureL: Double?, temperatureR: Double?
    var socL: Int?, socR: Int?
    var voltageL: Double?, voltageR: Double?
    var currentL: Double?, currentR: Double?
    var proximityL = 0, proximityR = 0

    init() {}

    init(_ p: [UInt8]) {
        let b = p.u8(1)
        hardwareRevision = String(format: "rev%X.%X", b >> 4, b & 0x0F)
        firmware = p.cString(2..<22)
        let o = 22 // start of fields after the firmware string (+touch fw byte at 22)
        localAddress = p.mac(o + 1)
        peerAddress = p.mac(o + 7)
        proximityL = Int(p.i16le(o + 25))
        proximityR = Int(p.i16le(o + 29))
        func nz(_ v: Int16) -> Int16? { v == 0 ? nil : v }
        temperatureL = nz(p.i16le(o + 33)).map { Double($0) / 10 }
        temperatureR = nz(p.i16le(o + 35)).map { Double($0) / 10 }
        socL = nz(p.i16le(o + 37)).map(Int.init)
        voltageL = nz(p.i16le(o + 39)).map { Double($0) / 100 }
        currentL = nz(p.i16le(o + 41)).map { Double($0) / -10 }
        socR = nz(p.i16le(o + 43)).map(Int.init)
        voltageR = nz(p.i16le(o + 45)).map { Double($0) / 100 }
        currentR = nz(p.i16le(o + 47)).map { Double($0) / -10 }
    }

    mutating func merge(_ other: DebugData) {
        self.hardwareRevision = other.hardwareRevision
        self.firmware = other.firmware
        self.localAddress = other.localAddress
        self.peerAddress = other.peerAddress
        proximityL = other.proximityL
        proximityR = other.proximityR
        temperatureL = other.temperatureL ?? temperatureL
        temperatureR = other.temperatureR ?? temperatureR
        socL = other.socL ?? socL
        socR = other.socR ?? socR
        voltageL = other.voltageL ?? voltageL
        voltageR = other.voltageR ?? voltageR
        currentL = other.currentL ?? currentL
        currentR = other.currentR ?? currentR
    }
}

/// CUSTOM_EQUALIZE_RECV (0x69) on Buds4 Pro: [active preset, band count, 6 × band-count gains].
/// Curve order: bass boost, soft, dynamic, clear, treble boost, custom.
struct EqualizerTable {
    var activePreset: UInt8 = 0
    var curves: [[Int]] = []

    init(_ p: [UInt8]) {
        activePreset = p.u8(0)
        let bands = Int(p.u8(1))
        guard bands > 0 else { return }
        var i = 2
        while i + bands <= p.count {
            curves.append(p[i..<(i + bands)].map { Int(Int8(bitPattern: $0)) })
            i += bands
        }
    }

    var custom: [Int]? { curves.count >= 6 ? curves[5] : nil }
}

/// SPATIAL_AUDIO_DATA (0xC2) event 0x20: game rotation vector as a quaternion (int16 LE / 10000).
/// The Buds4 Pro appends 28 more bytes per sample (looks like raw gyro/accel int32s; undecoded).
struct HeadPose {
    var quaternion: simd_quatf

    init?(_ p: [UInt8]) {
        guard p.u8(0) == 0x20, p.count >= 9 else { return nil }
        let v = (0..<4).map { Float(p.i16le(1 + $0 * 2)) / 10000 }
        quaternion = simd_quatf(ix: v[0], iy: v[1], iz: v[2], r: v[3]).normalized
    }
}
