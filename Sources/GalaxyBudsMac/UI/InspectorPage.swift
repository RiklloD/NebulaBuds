import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Live view of every SPP frame, plus a raw sender — the tool used to map the protocol.
struct InspectorPage: View {
    @Environment(BudsController.self) private var buds
    @State private var filter = ""
    @State private var hideNoise = true
    @State private var selection: LoggedFrame.ID?
    @State private var rawCommand = ""
    @State private var rawError: String?

    private static let noisyIDs: Set<UInt8> = [MsgID.debugEvent, 0xF4, 0xD6]

    var body: some View {
        @Bindable var buds = buds
        VStack(spacing: 0) {
            HStack {
                TextField("Filter by name or hex id (e.g. 61, NOISE)", text: $filter).textFieldStyle(.roundedBorder)
                Toggle("Hide debug logs", isOn: $hideNoise)
                Toggle("Pause", isOn: $buds.logPaused)
                Button("Export…", action: export)
                Button("Clear") { buds.clearLog() }
            }
            .padding(10)

            Table(rows, selection: $selection) {
                TableColumn("Time") { Text($0.date, format: .dateTime.hour().minute().second()).monospacedDigit() }
                    .width(70)
                TableColumn("") { Text($0.direction == .rx ? "←" : "→").foregroundStyle($0.direction == .rx ? .blue : .orange) }
                    .width(16)
                TableColumn("ID") { Text(String(format: "0x%02X", $0.frame.id)).monospaced() }.width(44)
                TableColumn("Message") { Text($0.name) }.width(min: 150, ideal: 220)
                TableColumn("Len") { Text("\($0.frame.payload.count)").monospacedDigit() }.width(36)
                TableColumn("Payload") { Text($0.frame.payload.hex).monospaced().lineLimit(1).truncationMode(.tail) }
            }
            .font(.system(size: 11))

            if let sel = selection, let f = buds.log.first(where: { $0.id == sel }) {
                detail(f).frame(height: 150)
            }

            Divider()
            HStack {
                Text("Send raw").foregroundStyle(.secondary)
                TextField("id payload…  e.g. 26   or   78 01", text: $rawCommand)
                    .textFieldStyle(.roundedBorder).monospaced()
                    .onSubmit(sendRaw)
                Button("Send", action: sendRaw).disabled(!buds.isConnected)
                if let rawError { Text(rawError).foregroundStyle(.red).font(.caption) }
            }
            .padding(10)
        }
    }

    private var rows: [LoggedFrame] {
        let q = filter.trimmingCharacters(in: .whitespaces).uppercased()
        return buds.log.reversed().filter { f in
            if hideNoise, Self.noisyIDs.contains(f.frame.id) { return false }
            guard !q.isEmpty else { return true }
            return f.name.uppercased().contains(q) || String(format: "%02X", f.frame.id) == q
        }
    }

    private func detail(_ f: LoggedFrame) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(f.name)  ·  header 0x\(String(format: "%04X", f.frame.header))  ·  seq \(f.frame.sequence)\(f.frame.isResponse ? "  ·  response" : "")")
                    .font(.headline)
                Text(offsetDump(f.frame.payload)).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                let ascii = String(decoding: f.frame.payload.map { (32...126).contains($0) ? $0 : 46 }, as: UTF8.self)
                Text(ascii).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .background(.background.secondary)
    }

    private func offsetDump(_ p: [UInt8]) -> String {
        stride(from: 0, to: p.count, by: 16).map { i in
            String(format: "%03d  ", i) + Array(p[i..<min(i + 16, p.count)]).hex
        }.joined(separator: "\n")
    }

    private func sendRaw() {
        let parts = rawCommand.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "," })
        let bytes = parts.compactMap { UInt8($0, radix: 16) }
        guard let id = bytes.first, bytes.count == parts.count else { rawError = "Use hex bytes"; return }
        guard id != MsgID.dumpBondedDevices else {
            rawError = "0xD4 dumps link keys of every paired device — blocked"
            return
        }
        rawError = nil
        buds.send(id, Array(bytes.dropFirst()))
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "buds-capture.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let text = buds.log.map { f in
            "\(iso.string(from: f.date)) \(f.direction == .rx ? "RX" : "TX") \(String(format: "0x%02X", f.frame.id)) hdr=\(String(format: "%04X", f.frame.header)) \(f.name) | \(f.frame.payload.hex)"
        }.joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
