/// Tracks requests separately from device state: neither the Adaptive EQ status layout
/// nor the candidate single-byte control payload has been verified on Buds4 Pro.
struct AdaptiveEQControl {
    enum State: Equatable {
        case idle
        case pending(Bool)
        case acknowledged(Bool)
        case failed(Failure)
    }

    enum Failure: Equatable {
        case sendFailed
        case timedOut
    }

    private(set) var state: State = .idle

    var isPending: Bool {
        if case .pending = state { return true }
        return false
    }

    /// Candidate encoding following the protocol's usual boolean-setting convention.
    /// Only one request may be outstanding because acknowledgements have no request ID.
    mutating func request(_ enabled: Bool) -> [UInt8]? {
        guard !isPending else { return nil }
        state = .pending(enabled)
        return [enabled ? 1 : 0]
    }

    @discardableResult
    mutating func receiveAcknowledgement(_ payload: [UInt8]) -> Bool {
        guard case .pending(let enabled) = state,
              payload == [MsgID.adaptiveEqualizerControl, enabled ? 1 : 0] else { return false }
        state = .acknowledged(enabled)
        return true
    }

    mutating func fail(_ failure: Failure) {
        guard isPending else { return }
        state = .failed(failure)
    }

    mutating func reset() { state = .idle }
}
