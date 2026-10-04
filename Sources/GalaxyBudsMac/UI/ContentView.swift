import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case noise = "Noise Control"
    case sound = "Sound"
    case touch = "Touch Controls"
    case headTracking = "Head Tracking"
    case find = "Find & Fit"
    case advanced = "Advanced"
    case diagnostics = "Diagnostics"
    case inspector = "Protocol Inspector"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "earbuds"
        case .noise: "ear.and.waveform"
        case .sound: "slider.vertical.3"
        case .touch: "hand.tap"
        case .headTracking: "move.3d"
        case .find: "location.magnifyingglass"
        case .advanced: "gearshape.2"
        case .diagnostics: "stethoscope"
        case .inspector: "waveform.path.ecg.rectangle"
        }
    }
}

struct ContentView: View {
    @Environment(BudsController.self) private var buds
    @State private var page: Page? = .overview

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { p in
                Label(p.rawValue, systemImage: p.symbol).tag(p)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            VStack(spacing: 0) {
                ConnectionBanner().padding([.horizontal, .top])
                detail
            }
            .navigationTitle(page?.rawValue ?? "")
            .navigationSubtitle(buds.deviceName)
        }
    }

    @ViewBuilder private var detail: some View {
        switch page ?? .overview {
        case .overview: OverviewPage()
        case .noise: NoiseControlPage()
        case .sound: SoundPage()
        case .touch: TouchPage()
        case .headTracking: HeadTrackingPage()
        case .find: FindPage()
        case .advanced: AdvancedPage()
        case .diagnostics: DiagnosticsPage()
        case .inspector: InspectorPage()
        }
    }
}

struct OverviewPage: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        let s = buds.status
        ScrollView {
            VStack(spacing: 28) {
                HStack {
                    BatteryGauge(title: "Left", symbol: "earbuds", level: buds.hasStatus ? s.batteryL : nil,
                                 charging: s.chargingL, detail: s.placementL.label)
                    BatteryGauge(title: "Case", symbol: "earbuds.case", level: buds.hasStatus && s.batteryCase > 0 ? s.batteryCase : nil,
                                 charging: s.chargingCase, detail: s.batteryCase == 0 ? "Not reporting" : nil)
                    BatteryGauge(title: "Right", symbol: "earbuds", level: buds.hasStatus ? s.batteryR : nil,
                                 charging: s.chargingR, detail: s.placementR.label)
                }
                .padding(.top, 8)

                GroupBox("Noise control") {
                    NoiseModePicker().padding(6)
                }

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow { quick("Equalizer", s.eq.label); quick("Ambient level", "\(s.ambientVolume)") }
                        GridRow { quick("Spatial audio", s.spatialAudio ? "On" : "Off"); quick("Touch controls", s.touchLock.enabled ? "On" : "Locked") }
                        GridRow { quick("Firmware", buds.firmwareL); quick("Color", buds.hasStatus ? s.colorName : "") }
                        GridRow { quick("Primary bud", buds.hasStatus ? (s.mainIsLeft ? "Left" : "Right") : ""); quick("Buds linked", s.coupled ? "Yes" : "No") }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
            }
            .padding(24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func quick(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(v.isEmpty ? "—" : v)
        }
    }
}
