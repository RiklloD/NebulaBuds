import SwiftUI

struct NoiseControlPage: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        let s = buds.status
        Form {
            Section { NoiseModePicker().padding(.vertical, 4) }

            Section("Noise cancelling") {
                Picker("ANC strength", selection: Binding(get: { s.noiseReductionLevel }, set: { buds.setNoiseReductionLevel($0) })) {
                    ForEach(0...4, id: \.self) { Text("\($0 + 1)").tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Noise controls with one earbud", isOn: Binding(get: { s.ancWithOneEarbud },
                                                                       set: { buds.setToggle(MsgID.ancWithOneEarbud, $0) }))
            }

            Section("Ambient sound") {
                LabeledContent("Ambient level") {
                    Slider(value: Binding(get: { Double(s.ambientVolume) }, set: { buds.setAmbientVolume(Int($0)) }),
                           in: 0...4, step: 1) { EmptyView() } minimumValueLabel: { Text("Low") } maximumValueLabel: { Text("High") }
                }
                Toggle("Customize ambient sound", isOn: Binding(get: { s.customAmbientOn }, set: {
                    buds.setCustomAmbient(on: $0, left: s.customAmbientL, right: s.customAmbientR, tone: s.customAmbientTone)
                }))
                if s.customAmbientOn {
                    stepper("Left level", s.customAmbientL, 0...4) { buds.setCustomAmbient(on: true, left: $0, right: s.customAmbientR, tone: s.customAmbientTone) }
                    stepper("Right level", s.customAmbientR, 0...4) { buds.setCustomAmbient(on: true, left: s.customAmbientL, right: $0, tone: s.customAmbientTone) }
                    stepper("Tone (soft → clear)", s.customAmbientTone, 0...4) { buds.setCustomAmbient(on: true, left: s.customAmbientL, right: s.customAmbientR, tone: $0) }
                }
            }

            Section("Conversation detection") {
                Toggle("Detect conversations", isOn: Binding(get: { s.detectConversations },
                                                             set: { buds.setToggle(MsgID.detectConversations, $0) }))
                Picker("Return to previous mode after", selection: Binding(get: { s.detectConversationsDuration },
                                                                          set: { buds.setDetectConversationsDuration($0) })) {
                    Text("5 seconds").tag(0); Text("10 seconds").tag(1); Text("15 seconds").tag(2)
                }
                .disabled(!s.detectConversations)
            }

            Section {
                cycleRow("Left earbud", s.cycleL) { buds.setNoiseCycle(left: $0, right: s.cycleR) }
                cycleRow("Right earbud", s.cycleR) { buds.setNoiseCycle(left: s.cycleL, right: $0) }
            } header: {
                Text("Touch & hold cycles through")
            } footer: {
                Text("Pick at least two modes per earbud.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(!buds.isConnected)
    }

    private func stepper(_ title: String, _ value: Int, _ range: ClosedRange<Int>, _ set: @escaping (Int) -> Void) -> some View {
        Stepper("\(title): \(value)", value: Binding(get: { value }, set: set), in: range)
    }

    private func cycleRow(_ title: String, _ cycle: NoiseCycle, _ set: @escaping (NoiseCycle) -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                ForEach([(NoiseCycle.anc, "ANC"), (.ambient, "Ambient"), (.adaptive, "Adaptive"), (.off, "Off")], id: \.1) { flag, name in
                    Toggle(name, isOn: Binding(get: { cycle.contains(flag) }, set: { on in
                        var c = cycle
                        if on { c.insert(flag) } else { c.remove(flag) }
                        if c.rawValue.nonzeroBitCount >= 2 { set(c) }
                    }))
                    .toggleStyle(.button)
                }
            }
        }
    }
}

struct SoundPage: View {
    @Environment(BudsController.self) private var buds
    @State private var bands: [Double] = []

    var body: some View {
        let s = buds.status
        Form {
            Section("Equalizer") {
                Picker("Preset", selection: Binding(get: { s.eq }, set: { buds.setEqualizer($0) })) {
                    ForEach(EqPreset.allCases) { Text($0.label).tag($0) }
                }
                if let table = buds.eqTable, s.eq != .off, s.eq != .custom, Int(s.eq.rawValue) <= table.curves.count {
                    LabeledContent("Curve") { curve(table.curves[Int(s.eq.rawValue) - 1].map(Double.init)) }
                }
            }

            Section {
                HStack {
                    Button("Enable") { buds.setAdaptiveEqualizer(true) }
                    Button("Disable") { buds.setAdaptiveEqualizer(false) }
                    Spacer()
                    if buds.adaptiveEQ.isPending {
                        ProgressView().controlSize(.small)
                    }
                }
                .disabled(!buds.adaptiveEQAvailable || buds.adaptiveEQ.isPending)
                Text(adaptiveEQMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Adaptive EQ · Experimental")
            } footer: {
                Text("Samsung Adaptive EQ adjusts sound for how the earbuds fit. These controls still need verification on Buds4 Pro. An acknowledged request does not confirm the active setting.")
            }

            Section {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(bands.indices, id: \.self) { i in
                        VStack(spacing: 6) {
                            Text(bands[i] > 0 ? "+\(Int(bands[i]))" : "\(Int(bands[i]))").font(.caption.monospacedDigit())
                            Slider(value: $bands[i], in: -6...6, step: 1) { editing in
                                if !editing { buds.setCustomBands(bands.map { Int($0) }) }
                            }
                            .rotationEffect(.degrees(-90))
                            .frame(width: 140, height: 24)
                            .frame(width: 28, height: 140)
                            Text(Self.bandLabels[i]).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                HStack {
                    Button("Flat") { bands = Array(repeating: 0, count: 9); buds.setCustomBands(Array(repeating: 0, count: 9)) }
                    if let c = buds.eqTable?.custom {
                        Button("Load from earbuds") { bands = c.map(Double.init); buds.setCustomBands(c) }
                    }
                }
            } header: {
                Text("Custom equalizer")
            } footer: {
                Text("Changing a band switches to the Custom preset. The Buds4 Pro drops the custom curve when noise control changes, so this app re-sends it automatically.")
                    .foregroundStyle(.secondary)
            }

            Section("Spatial & balance") {
                Toggle("360 Audio (spatial audio)", isOn: Binding(get: { s.spatialAudio }, set: { buds.setToggle(MsgID.spatialAudio, $0) }))
                LabeledContent("Left/right balance") {
                    Slider(value: Binding(get: { Double(s.stereoBalance) }, set: { buds.setStereoBalance(Int($0)) }), in: 0...32, step: 1) {
                        EmptyView()
                    } minimumValueLabel: { Text("L") } maximumValueLabel: { Text("R") }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(!buds.isConnected)
        .onAppear { bands = buds.customBands.map(Double.init) }
    }

    static let bandLabels = ["Sub", "Bass", "Low", "Lo-mid", "Mid", "Hi-mid", "Pres", "Treble", "Air"]

    private var adaptiveEQMessage: String {
        guard buds.isConnected else { return "Connect your earbuds to use Adaptive EQ controls." }
        guard buds.adaptiveEQAvailable else { return "Available for Galaxy Buds4 Pro once the device is identified." }
        switch buds.adaptiveEQ.state {
        case .idle: return "Active setting unavailable. Choose Enable or Disable to try a request."
        case .pending(let enabled): return "Waiting for earbuds to acknowledge \(enabled ? "Enable" : "Disable")…"
        case .acknowledged(let enabled): return "\(enabled ? "Enable" : "Disable") request acknowledged. Active setting unavailable."
        case .failed(.sendFailed): return "Could not send the request. Check the connection and try again."
        case .failed(.timedOut): return "No acknowledgement received. The setting may not have changed."
        }
    }

    private func curve(_ values: [Double]) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(values.indices, id: \.self) { i in
                let v = values[i]
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 8, height: max(2, abs(v) * 3))
                    .offset(y: v > 0 ? -abs(v) * 1.5 : abs(v) * 1.5)
            }
        }
        .frame(height: 40)
    }
}

struct TouchPage: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        let s = buds.status
        let lock = s.touchLock
        Form {
            Section {
                Toggle("Touch controls", isOn: bind(lock, \.enabled))
            }
            Section("Allowed gestures") {
                Toggle("Single tap (play/pause)", isOn: bind(lock, \.singleTap))
                Toggle("Double tap (next track / answer call)", isOn: bind(lock, \.doubleTap))
                Toggle("Triple tap (previous track)", isOn: bind(lock, \.tripleTap))
                Toggle("Touch and hold", isOn: bind(lock, \.touchAndHold))
                Toggle("Double tap during calls", isOn: bind(lock, \.doubleTapCall))
                Toggle("Touch and hold during calls", isOn: bind(lock, \.touchAndHoldCall))
            }
            .disabled(!lock.enabled)

            Section("Touch and hold action") {
                Picker("Left earbud", selection: Binding(get: { s.touchL }, set: { buds.setTouchActions(left: $0, right: s.touchR) })) {
                    ForEach(TouchAction.allCases) { Text($0.label).tag($0) }
                }
                Picker("Right earbud", selection: Binding(get: { s.touchR }, set: { buds.setTouchActions(left: s.touchL, right: $0) })) {
                    ForEach(TouchAction.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(!buds.isConnected)
    }

    private func bind(_ lock: TouchLock, _ kp: WritableKeyPath<TouchLock, Bool>) -> Binding<Bool> {
        Binding(get: { lock[keyPath: kp] }, set: { var l = lock; l[keyPath: kp] = $0; buds.setTouchLock(l) })
    }
}

struct AdvancedPage: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        let s = buds.status
        Form {
            Section("Connection") {
                toggle("Seamless earbud connection", s.seamlessConnection, MsgID.seamlessConnection, inverted: true,
                       footer: "Automatically switch between devices signed in to the same Samsung account.")
            }
            Section("Calls") {
                toggle("Ambient sound during calls (sidetone)", s.sidetone, MsgID.sidetone)
                toggle("Extra-clear call sound", s.extraClearCall, MsgID.extraClearCall)
                toggle("Switch call audio when earbuds are worn", s.callPathControl, MsgID.callPathControl, inverted: true)
            }
            Section("Playback") {
                toggle("Pause media when an earbud is removed", s.autoPauseResume, MsgID.pauseWhenOneBudRemoved)
                toggle("Speak seamlessly (Voice assistant)", s.speakSeamlessly, MsgID.speakSeamlessly)
            }
        }
        .formStyle(.grouped)
        .disabled(!buds.isConnected)
    }

    private func toggle(_ title: String, _ value: Bool, _ id: UInt8, inverted: Bool = false, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: Binding(get: { value }, set: { buds.setToggle(id, $0, inverted: inverted) }))
            if let footer { Text(footer).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct FindPage: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "speaker.wave.3.fill").font(.largeTitle).foregroundStyle(buds.findingBuds ? .orange : .secondary)
                        .symbolEffect(.variableColor.iterative, isActive: buds.findingBuds)
                    VStack(alignment: .leading) {
                        Text("Find my earbuds").font(.headline)
                        Text("Plays a loud beeping sound. Take the earbuds out of your ears first.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(buds.findingBuds ? "Stop" : "Start") { buds.findingBuds ? buds.stopFind() : buds.startFind() }
                        .buttonStyle(.borderedProminent).tint(buds.findingBuds ? .red : .accentColor)
                }
                if buds.findingBuds {
                    Toggle("Mute left", isOn: Binding(get: { buds.mutedL }, set: { buds.setMute(left: $0, right: buds.mutedR) }))
                    Toggle("Mute right", isOn: Binding(get: { buds.mutedR }, set: { buds.setMute(left: buds.mutedL, right: $0) }))
                }
            }

            Section {
                HStack {
                    Image(systemName: "ear.badge.checkmark").font(.largeTitle).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Earbud fit test").font(.headline)
                        Text("Put both earbuds in, then start. A test tone plays for a few seconds.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    if buds.fitTestRunning {
                        ProgressView().controlSize(.small)
                        Button("Cancel") { buds.stopFitTest() }
                    } else {
                        Button("Start test") { buds.startFitTest() }
                    }
                }
                if let r = buds.fitResult {
                    InfoRow("Left", fitLabel(r.left))
                    InfoRow("Right", fitLabel(r.right))
                }
            }
        }
        .formStyle(.grouped)
        .disabled(!buds.isConnected)
    }

    private func fitLabel(_ v: UInt8) -> String {
        switch v { case 1: "Good seal ✓"; case 0: "Poor seal — try another ear tip size"; default: "Test failed" }
    }
}

struct DiagnosticsPage: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        let d = buds.debug
        Form {
            Section("Device") {
                InfoRow("Model", buds.sku)
                InfoRow("Color", buds.hasStatus ? buds.status.colorName : "")
                InfoRow("Hardware", d.hardwareRevision)
                InfoRow("Firmware (L / R)", "\(buds.firmwareL)  /  \(buds.firmwareR)")
                InfoRow("Serial (L / R)", "\(buds.serialL)  /  \(buds.serialR)")
                InfoRow("Case firmware", buds.caseFirmware)
                InfoRow("Case serial", buds.caseSerial)
                InfoRow("Bluetooth address (L)", d.localAddress)
                InfoRow("Bluetooth address (R)", d.peerAddress)
            }
            Section("Battery & sensors") {
                InfoRow("Temperature (L / R)", "\(fmt(d.temperatureL, "%.1f °C"))  /  \(fmt(d.temperatureR, "%.1f °C"))")
                InfoRow("Fuel gauge (L / R)", "\(d.socL.map { "\($0)%" } ?? "—")  /  \(d.socR.map { "\($0)%" } ?? "—")")
                InfoRow("Cell voltage (L / R)", "\(fmt(d.voltageL, "%.2f V"))  /  \(fmt(d.voltageR, "%.2f V"))")
                InfoRow("Charge cycles (L / R)", "\(fmt(buds.batteryCyclesL, "%.1f"))  /  \(fmt(buds.batteryCyclesR, "%.1f"))")
                InfoRow("Proximity (L / R)", "\(d.proximityL)  /  \(d.proximityR)")
            }
            Section("Status packet") {
                InfoRow("Revision", "\(buds.status.revision)")
                InfoRow("Undecoded tail bytes", buds.status.unknownTail.hex)
            }
            Section {
                Button("Refresh") { buds.refreshDiagnostics() }
            }
        }
        .formStyle(.grouped)
    }

    private func fmt(_ v: Double?, _ f: String) -> String { v.map { String(format: f, $0) } ?? "—" }
}
