import SwiftUI

struct BatteryGauge: View {
    let title: String
    let symbol: String
    let level: Int?
    var charging = false
    var detail: String?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(level ?? 0) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: level)
                Image(systemName: symbol).font(.system(size: 26, weight: .light))
            }
            .frame(width: 84, height: 84)
            VStack(spacing: 2) {
                Text(title).font(.headline)
                HStack(spacing: 3) {
                    if charging { Image(systemName: "bolt.fill").foregroundStyle(.green) }
                    Text(level.map { "\($0)%" } ?? "—").monospacedDigit()
                }
                .foregroundStyle(.secondary)
                if let detail { Text(detail).font(.caption).foregroundStyle(.tertiary) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tint: Color {
        guard let level else { return .gray }
        return level <= 15 ? .red : level <= 30 ? .orange : .green
    }
}

struct NoiseModePicker: View {
    @Environment(BudsController.self) private var buds
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            ForEach(NoiseControlMode.allCases) { mode in
                let selected = buds.status.noiseControl == mode
                Button {
                    buds.setNoiseControl(mode)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mode.symbol).font(.system(size: compact ? 16 : 22))
                        Text(compact ? shortLabel(mode) : mode.label).font(compact ? .caption2 : .caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 48 : 64)
                    .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(!buds.isConnected)
    }

    private func shortLabel(_ m: NoiseControlMode) -> String {
        m == .anc ? "ANC" : m.label
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        LabeledContent(label) {
            Text(value.isEmpty ? "—" : value).textSelection(.enabled).monospacedDigit()
        }
    }
}

struct ConnectionBanner: View {
    @Environment(BudsController.self) private var buds

    var body: some View {
        switch buds.linkState {
        case .connected:
            EmptyView()
        case .connecting(let name):
            banner("Connecting to \(name)…", symbol: "antenna.radiowaves.left.and.right", progress: true)
        case .failed(let msg):
            banner(msg, symbol: "exclamationmark.triangle", progress: false)
        case .idle:
            banner("Starting…", symbol: "earbuds", progress: true)
        }
    }

    private func banner(_ text: String, symbol: String, progress: Bool) -> some View {
        HStack {
            Image(systemName: symbol)
            Text(text)
            Spacer()
            if progress { ProgressView().controlSize(.small) } else { Button("Retry") { buds.reconnect() } }
        }
        .padding(10)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}
