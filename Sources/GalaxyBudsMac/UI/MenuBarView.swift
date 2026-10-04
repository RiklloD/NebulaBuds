import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    @Environment(BudsController.self) private var buds
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.status == .requiresApproval

    var body: some View {
        let s = buds.status
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(buds.deviceName).font(.headline)
                Spacer()
                Circle().fill(buds.isConnected ? .green : .secondary).frame(width: 8, height: 8)
            }

            if buds.hasStatus {
                HStack {
                    battery("L", s.batteryL, s.chargingL, s.placementL)
                    battery("Case", s.batteryCase > 0 ? s.batteryCase : nil, s.chargingCase, nil)
                    battery("R", s.batteryR, s.chargingR, s.placementR)
                }
            } else {
                ConnectionBanner()
            }

            NoiseModePicker(compact: true)

            Divider()
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { _, on in
                    LaunchAtLogin.set(on)
                    needsApproval = LaunchAtLogin.status == .requiresApproval
                }
            if needsApproval {
                Button("Allow in System Settings → Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    .buttonStyle(.link).font(.caption)
            }
            HStack {
                Button("Open NebulaBuds…") {
                    NSApp.setActivationPolicy(.regular)
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 300)
    }

    private func battery(_ label: String, _ level: Int?, _ charging: Bool, _ placement: Placement?) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                if charging { Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.green) }
                Text(level.map { "\($0)%" } ?? "—").font(.title3.monospacedDigit())
            }
            if let placement { Text(placement.label).font(.caption2).foregroundStyle(.tertiary) }
        }
        .frame(maxWidth: .infinity)
    }
}
