import Foundation
import Observation
import simd

struct LoggedFrame: Identifiable {
    enum Direction { case rx, tx }
    let id = UUID()
    let date = Date()
    let direction: Direction
    let frame: SppFrame
    var name: String { MsgID.name(frame.id) }
}

@MainActor
@Observable
final class BudsController {
    static let shared = BudsController()

    // Connection
    private(set) var linkState: BudsLink.State = .idle
    var isConnected: Bool { if case .connected = linkState { true } else { false } }
    var deviceName: String {
        switch linkState {
        case .connecting(let n), .connected(let n): n
        default: "Galaxy Buds"
        }
    }

    // Decoded device state
    private(set) var status = ExtendedStatus()
    private(set) var hasStatus = false
    private(set) var debug = DebugData()
    private(set) var firmwareL = ""
    private(set) var firmwareR = ""
    private(set) var serialL = ""
    private(set) var serialR = ""
    private(set) var sku = ""
    private(set) var caseFirmware = ""
    private(set) var caseSerial = ""
    private(set) var batteryCyclesL: Double?
    private(set) var batteryCyclesR: Double?
    private(set) var eqTable: EqualizerTable?
    private(set) var adaptiveEQ = AdaptiveEQControl()
    private(set) var adaptiveEQAvailable = false
    private var adaptiveEQTimeout: Task<Void, Never>?
    private(set) var fitResult: (left: UInt8, right: UInt8)?
    private(set) var fitTestRunning = false
    private(set) var findingBuds = false
    private(set) var mutedL = false
    private(set) var mutedR = false

    // Head tracking
    private(set) var headTracking = false
    private(set) var pose: simd_quatf?
    private(set) var poseRate = 0.0
    private var poseReference: simd_quatf?
    private var poseCount = 0
    private var poseRateStart = Date()
    private var keepAliveTimer: Timer?

    // Custom EQ the user edits locally; pushed to the buds (firmware drops it on NC switch).
    var customBands: [Int] = UserDefaults.standard.array(forKey: "customBands") as? [Int] ?? Array(repeating: 0, count: 9)

    // Protocol inspector
    private(set) var log: [LoggedFrame] = []
    var logPaused = false
    private(set) var frameCounts: [UInt8: Int] = [:]

    private let link = BudsLink()
    private var pollTimer: Timer?
    /// Set BUDS_TRACE=1 to print link state and every frame to stderr.
    private let trace = ProcessInfo.processInfo.environment["BUDS_TRACE"] != nil

    private init() {
        link.onState = { [weak self] in self?.linkStateChanged($0) }
        link.onFrame = { [weak self] in self?.handle($0) }
        link.onSend = { [weak self] in self?.record($0, .tx) }
    }

    func start() {
        link.start(preferredAddress: UserDefaults.standard.string(forKey: "lastDevice"))
    }

    func reconnect() {
        if let dev = link.device { link.connect(dev) } else { start() }
    }

    private func linkStateChanged(_ state: BudsLink.State) {
        adaptiveEQTimeout?.cancel()
        adaptiveEQTimeout = nil
        adaptiveEQ.reset()
        adaptiveEQAvailable = false
        linkState = state
        if trace { FileHandle.standardError.write(Data("STATE \(state)\n".utf8)) }
        guard case .connected = state else {
            pollTimer?.invalidate()
            stopHeadTracking()
            return
        }
        UserDefaults.standard.set(link.device?.addressString, forKey: "lastDevice")
        handshake()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(MsgID.debugGetAllData) }
        }
    }

    /// Mirrors what the official app sends on connect.
    private func handshake() {
        send(MsgID.managerInfo, [1, 1, 34]) // [version, client type = Samsung, Android SDK]
        for id in [MsgID.debugGetAllData, MsgID.debugSerialNumber, MsgID.debugSku,
                   MsgID.socBatteryCycle, MsgID.customEqualizerRecv] {
            send(id)
        }
    }

    func send(_ id: UInt8, _ payload: [UInt8] = []) {
        link.send(id, payload)
    }

    // MARK: Incoming

    private func record(_ frame: SppFrame, _ dir: LoggedFrame.Direction) {
        if trace {
            FileHandle.standardError.write(Data("\(dir == .rx ? "RX" : "TX") \(MsgID.name(frame.id)) | \(frame.payload.hex)\n".utf8))
        }
        frameCounts[frame.id, default: 0] += 1
        guard !logPaused else { return }
        // Head-tracking samples arrive at ~12 Hz; keep them out of the log unless nothing else is there.
        if frame.id == MsgID.spatialAudioData, frame.payload.first == 0x20, headTracking { return }
        log.append(LoggedFrame(direction: dir, frame: frame))
        if log.count > 3000 { log.removeFirst(log.count - 3000) }
    }

    func clearLog() {
        log.removeAll()
        frameCounts.removeAll()
    }

    private func handle(_ frame: SppFrame) {
        record(frame, .rx)
        let p = frame.payload
        switch frame.id {
        case MsgID.extendedStatusUpdated:
            status = ExtendedStatus(p)
            hasStatus = true
        case MsgID.statusUpdated:
            let s = BasicStatus(p)
            status.batteryL = s.batteryL
            status.batteryR = s.batteryR
            status.batteryCase = s.batteryCase
            status.placementL = s.placementL
            status.placementR = s.placementR
            status.chargingL = s.chargingL
            status.chargingR = s.chargingR
            status.chargingCase = s.chargingCase
        case MsgID.noiseControlsUpdate:
            if let m = NoiseControlMode(rawValue: p.u8(0)) {
                status.noiseControl = m
                reapplyCustomEqIfNeeded()
            }
        case MsgID.touchUpdated:
            status.touchLock.enabled = !p.bool(0)
        case MsgID.ack:
            applyAck(p)
        case MsgID.debugGetAllData:
            debug.merge(DebugData(p))
        case MsgID.versionInfoLong:
            firmwareL = p.cString(2..<22)
            firmwareR = p.cString(22..<42)
        case MsgID.debugSerialNumber:
            serialL = p.cString(0..<11)
            serialR = p.cString(11..<22)
        case MsgID.debugSku:
            sku = p.cString(0..<14)
            adaptiveEQAvailable = sku.hasPrefix("SM-R640")
        case MsgID.cradleSerialNumber:
            caseFirmware = p.cString(0..<13)
            caseSerial = p.cString(13..<p.count)
        case MsgID.socBatteryCycle:
            batteryCyclesL = Double(p.u64be(0)) / 10000
            batteryCyclesR = Double(p.u64be(8)) / 10000
        case MsgID.customEqualizerRecv:
            let table = EqualizerTable(p)
            eqTable = table
            if UserDefaults.standard.array(forKey: "customBands") == nil, let c = table.custom {
                customBands = c
            }
        case MsgID.fitTestResult:
            fitResult = (p.u8(0), p.u8(1))
            fitTestRunning = false
        case MsgID.muteEarbudStatus:
            mutedL = p.bool(0)
            mutedR = p.bool(1)
        case MsgID.spatialAudioData:
            if let pose = HeadPose(p) { handlePose(pose) }
        default:
            break
        }
    }

    /// 0x42 = [command id, echoed value(s)]; keep local state in sync with what the buds accepted.
    private func applyAck(_ p: [UInt8]) {
        if adaptiveEQ.receiveAcknowledgement(p) {
            adaptiveEQTimeout?.cancel()
            adaptiveEQTimeout = nil
        }
        guard let id = p.first else { return }
        let v = p.u8(1)
        switch id {
        case MsgID.noiseControls: status.noiseControl = NoiseControlMode(rawValue: v) ?? status.noiseControl
        case MsgID.ambientVolume: status.ambientVolume = Int(v)
        case MsgID.noiseReductionLevel: status.noiseReductionLevel = Int(v)
        case MsgID.equalizer: status.eq = EqPreset(rawValue: v) ?? status.eq
        case MsgID.detectConversations: status.detectConversations = v == 1
        case MsgID.detectConversationsDuration: status.detectConversationsDuration = Int(v)
        case MsgID.ancWithOneEarbud: status.ancWithOneEarbud = v == 1
        case MsgID.sidetone: status.sidetone = v == 1
        case MsgID.callPathControl: status.callPathControl = v == 0
        case MsgID.seamlessConnection: status.seamlessConnection = v == 0
        case MsgID.spatialAudio: status.spatialAudio = v == 1
        case MsgID.speakSeamlessly: status.speakSeamlessly = v == 1
        case MsgID.extraClearCall: status.extraClearCall = v == 1
        case MsgID.pauseWhenOneBudRemoved: status.autoPauseResume = v == 1
        case MsgID.hearingEnhancements: status.stereoBalance = Int(v)
        case MsgID.touchAndHoldNoiseControls:
            status.cycleL = NoiseCycle(rawValue: p.u8(1))
            status.cycleR = NoiseCycle(rawValue: p.u8(2))
        case MsgID.lockTouchpad:
            var t = TouchLock()
            (t.enabled, t.singleTap, t.doubleTap, t.tripleTap, t.touchAndHold, t.doubleTapCall, t.touchAndHoldCall) =
                (p.bool(1), p.bool(2), p.bool(3), p.bool(4), p.bool(5), p.bool(6), p.bool(7))
            status.touchLock = t
        case MsgID.customizeAmbient:
            status.customAmbientOn = p.bool(1)
            status.customAmbientL = Int(p.u8(2))
            status.customAmbientR = Int(p.u8(3))
            status.customAmbientTone = Int(p.u8(4))
        default: break
        }
    }

    // MARK: Commands

    func setAdaptiveEqualizer(_ enabled: Bool) {
        guard isConnected, adaptiveEQAvailable,
              let payload = adaptiveEQ.request(enabled) else { return }
        guard link.send(MsgID.adaptiveEqualizerControl, payload) else {
            adaptiveEQ.fail(.sendFailed)
            return
        }
        adaptiveEQTimeout?.cancel()
        adaptiveEQTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) }
            catch { return }
            guard let self else { return }
            self.adaptiveEQ.fail(.timedOut)
            self.adaptiveEQTimeout = nil
        }
    }

    func setNoiseControl(_ mode: NoiseControlMode) {
        status.noiseControl = mode
        send(MsgID.noiseControls, [mode.rawValue])
    }

    func setAmbientVolume(_ v: Int) { status.ambientVolume = v; send(MsgID.ambientVolume, [UInt8(v)]) }
    func setNoiseReductionLevel(_ v: Int) { status.noiseReductionLevel = v; send(MsgID.noiseReductionLevel, [UInt8(v)]) }

    func setCustomAmbient(on: Bool, left: Int, right: Int, tone: Int) {
        (status.customAmbientOn, status.customAmbientL, status.customAmbientR, status.customAmbientTone) = (on, left, right, tone)
        send(MsgID.customizeAmbient, [on ? 1 : 0, UInt8(left), UInt8(right), UInt8(tone)])
    }

    func setNoiseCycle(left: NoiseCycle, right: NoiseCycle) {
        (status.cycleL, status.cycleR) = (left, right)
        send(MsgID.touchAndHoldNoiseControls, [left.rawValue, right.rawValue])
    }

    func setToggle(_ id: UInt8, _ on: Bool, inverted: Bool = false) {
        send(id, [(on != inverted) ? 1 : 0])
    }

    func setDetectConversationsDuration(_ v: Int) {
        status.detectConversationsDuration = v
        send(MsgID.detectConversationsDuration, [UInt8(v)])
    }

    func setStereoBalance(_ v: Int) { status.stereoBalance = v; send(MsgID.hearingEnhancements, [UInt8(v)]) }

    func setEqualizer(_ preset: EqPreset) {
        status.eq = preset
        if preset == .custom { pushCustomBands() }
        send(MsgID.equalizer, [preset.rawValue])
    }

    func setCustomBands(_ bands: [Int]) {
        customBands = bands
        UserDefaults.standard.set(bands, forKey: "customBands")
        pushCustomBands()
        if status.eq != .custom { setEqualizer(.custom) }
    }

    private func pushCustomBands() {
        send(MsgID.customEqualizerSend, [UInt8(customBands.count)] + customBands.map { UInt8(bitPattern: Int8($0)) })
    }

    /// Buds4 Pro firmware forgets the custom band table on noise-control switches.
    private func reapplyCustomEqIfNeeded() {
        guard status.eq == .custom, UserDefaults.standard.array(forKey: "customBands") != nil else { return }
        pushCustomBands()
    }

    func setTouchLock(_ lock: TouchLock) {
        status.touchLock = lock
        send(MsgID.lockTouchpad, lock.payload)
    }

    func setTouchActions(left: TouchAction, right: TouchAction) {
        (status.touchL, status.touchR) = (left, right)
        send(MsgID.touchpadOption, [left.rawValue, right.rawValue])
    }

    func startFind() { findingBuds = true; send(MsgID.findStart) }
    func stopFind() { findingBuds = false; send(MsgID.findStop) }
    func setMute(left: Bool, right: Bool) { (mutedL, mutedR) = (left, right); send(MsgID.muteEarbud, [left ? 1 : 0, right ? 1 : 0]) }

    func startFitTest() { fitResult = nil; fitTestRunning = true; send(MsgID.fitTest, [1]) }
    func stopFitTest() { fitTestRunning = false; send(MsgID.fitTest, [0]) }

    func refreshDiagnostics() {
        for id in [MsgID.debugGetAllData, MsgID.socBatteryCycle, MsgID.debugSerialNumber, MsgID.debugSku] { send(id) }
    }

    // MARK: Head tracking

    func startHeadTracking() {
        guard isConnected, !headTracking else { return }
        headTracking = true
        poseCount = 0
        poseRateStart = Date()
        send(MsgID.spatialAudioControl, [0]) // attach
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(MsgID.spatialAudioControl, [4]) }
        }
    }

    func stopHeadTracking() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        guard headTracking else { return }
        headTracking = false
        send(MsgID.spatialAudioControl, [1]) // detach
    }

    func recenterHead() { poseReference = rawPose }

    private var rawPose: simd_quatf?

    private func handlePose(_ p: HeadPose) {
        rawPose = p.quaternion
        if poseReference == nil { poseReference = p.quaternion }
        pose = poseReference!.inverse * p.quaternion
        poseCount += 1
        let dt = Date().timeIntervalSince(poseRateStart)
        if dt > 2 {
            poseRate = Double(poseCount) / dt
            poseCount = 0
            poseRateStart = Date()
        }
    }
}
