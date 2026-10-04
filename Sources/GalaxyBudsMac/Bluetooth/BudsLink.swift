import Foundation
import IOBluetooth

/// RFCOMM transport to the Buds' Galaxy Wearable ("GEARMANAGER") SPP service.
@MainActor
final class BudsLink: NSObject {
    /// Service class UUID advertised by Buds+ and newer as "GEARMANAGER".
    static let serviceUUID: [UInt8] = [
        0x2E, 0x73, 0xA4, 0xAD, 0x33, 0x2D, 0x41, 0xFC, 0x90, 0xE2, 0x16, 0xBE, 0xF0, 0x65, 0x23, 0xF2,
    ]

    enum State: Equatable {
        case idle
        case connecting(String)
        case connected(String)
        case failed(String)
    }

    var onState: ((State) -> Void)?
    var onFrame: ((SppFrame) -> Void)?
    var onSend: ((SppFrame) -> Void)?

    private(set) var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var parser = SppFrameParser()
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotification: IOBluetoothUserNotification?
    private var state: State = .idle { didSet { onState?(state) } }

    /// Paired devices that expose the Galaxy Wearable SPP service.
    ///
    /// On macOS 27 the objects from `pairedDevices()` are stale snapshots (duplicated, and
    /// `isConnected()` is always false), so each one is re-resolved by address.
    static func pairedBuds() -> [IOBluetoothDevice] {
        let uuid = IOBluetoothSDPUUID(bytes: serviceUUID, length: serviceUUID.count)
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        var seen = Set<String>()
        return paired.compactMap { snapshot -> IOBluetoothDevice? in
            guard let address = snapshot.addressString, seen.insert(address).inserted else { return nil }
            let dev = IOBluetoothDevice(addressString: address) ?? snapshot
            if dev.getServiceRecord(for: uuid) != nil { return dev }
            // No cached SDP yet: fall back to the name.
            return dev.services == nil && (dev.name ?? "").localizedCaseInsensitiveContains("buds") ? dev : nil
        }
    }

    func start(preferredAddress: String?) {
        if connectNotification == nil {
            connectNotification = IOBluetoothDevice.register(
                forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        }
        let candidates = Self.pairedBuds()
        guard let pick = candidates.first(where: { $0.isConnected() })
            ?? candidates.first(where: { $0.addressString == preferredAddress })
            ?? candidates.first
        else {
            state = .failed("No paired Galaxy Buds found. Pair them in System Settings → Bluetooth.")
            return
        }
        // Try even if not reported connected: opening RFCOMM brings the link up when the buds are awake.
        connect(pick)
    }

    func connect(_ dev: IOBluetoothDevice, sdpRetried: Bool = false) {
        disconnect()
        device = dev
        let name = dev.name ?? dev.addressString ?? "Galaxy Buds"
        state = .connecting(name)

        let uuid = IOBluetoothSDPUUID(bytes: Self.serviceUUID, length: Self.serviceUUID.count)
        var channelID: BluetoothRFCOMMChannelID = 0
        let record = dev.getServiceRecord(for: uuid)
        if record == nil, !sdpRetried {
            // SDP results arrive asynchronously; query and retry once.
            dev.performSDPQuery(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                self?.connect(dev, sdpRetried: true)
            }
            return
        }
        guard let record, record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess else {
            state = .failed("\(name) does not expose the Galaxy Wearable service (SDP).")
            return
        }

        var ch: IOBluetoothRFCOMMChannel?
        let result = dev.openRFCOMMChannelAsync(&ch, withChannelID: channelID, delegate: self)
        guard result == kIOReturnSuccess else {
            state = .failed(String(format: "Could not open RFCOMM channel %d (0x%08X).", channelID, result))
            return
        }
        channel = ch
        disconnectNotification = dev.register(
            forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
    }

    func disconnect() {
        channel?.setDelegate(nil)
        channel?.close()
        channel = nil
        disconnectNotification?.unregister()
        disconnectNotification = nil
        parser = SppFrameParser()
    }

    var isOpen: Bool { channel?.isOpen() ?? false }

    @discardableResult
    func send(_ id: UInt8, _ payload: [UInt8] = []) -> Bool {
        guard let channel, channel.isOpen() else { return false }
        let frame = SppFrame(id: id, payload: payload)
        var bytes = frame.encoded()
        let result = channel.writeSync(&bytes, length: UInt16(bytes.count))
        if result == kIOReturnSuccess { onSend?(frame) }
        return result == kIOReturnSuccess
    }

    // MARK: IOBluetooth callbacks

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device snapshot: IOBluetoothDevice) {
        guard !isOpen, let address = snapshot.addressString,
              let dev = IOBluetoothDevice(addressString: address) else { return }
        let uuid = IOBluetoothSDPUUID(bytes: Self.serviceUUID, length: Self.serviceUUID.count)
        let isBuds = dev.getServiceRecord(for: uuid) != nil
            || (dev.name ?? "").localizedCaseInsensitiveContains("buds")
        guard isBuds else { return }
        // Give the audio profiles a moment to settle before opening SPP.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.isOpen else { return }
            self.connect(dev)
        }
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device dev: IOBluetoothDevice) {
        disconnect()
        state = .failed("\(dev.name ?? "Buds") disconnected.")
    }
}

extension BudsLink: IOBluetoothRFCOMMChannelDelegate {
    nonisolated func rfcommChannelOpenComplete(_ ch: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        MainActor.assumeIsolated {
            let name = device?.name ?? "Galaxy Buds"
            state = error == kIOReturnSuccess
                ? .connected(name)
                : .failed(String(format: "RFCOMM open failed (0x%08X).", error))
        }
    }

    nonisolated func rfcommChannelClosed(_ ch: IOBluetoothRFCOMMChannel!) {
        MainActor.assumeIsolated {
            guard ch === channel else { return }
            channel = nil
            state = .failed("Connection closed.")
        }
    }

    nonisolated func rfcommChannelData(_ ch: IOBluetoothRFCOMMChannel!, data ptr: UnsafeMutableRawPointer!, length: Int) {
        let bytes = Array(UnsafeBufferPointer(start: ptr.assumingMemoryBound(to: UInt8.self), count: length))
        MainActor.assumeIsolated {
            for frame in parser.feed(bytes) { onFrame?(frame) }
        }
    }
}
