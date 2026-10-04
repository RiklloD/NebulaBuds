import Testing
@testable import GalaxyBudsMac

/// Candidate protocol tests, not hardware captures. An ACK is never treated as
/// proof of the active Adaptive EQ setting.
struct AdaptiveEQTests {
    @Test func serializesRequestsAndMatchesAcknowledgements() {
        var control = AdaptiveEQControl()
        #expect(control.state == .idle)
        #expect(control.request(true) == [1])
        #expect(control.isPending)
        #expect(control.request(false) == nil)
        #expect(control.receiveAcknowledgement([MsgID.equalizer, 1]) == false)
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 0]) == false)
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl]) == false)
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 1, 0]) == false)
        #expect(control.state == .pending(true))
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 1]) == true)
        #expect(control.state == .acknowledged(true))
        #expect(!control.isPending)
        #expect(control.request(false) == [0])
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 0]) == true)
        #expect(control.state == .acknowledged(false))
    }

    @Test func timeoutAndDisconnectDoNotReportSuccess() {
        var control = AdaptiveEQControl()
        _ = control.request(true)
        control.fail(.timedOut)
        #expect(control.state == .failed(.timedOut))
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 1]) == false)
        #expect(control.request(false) == [0])
        control.reset()
        #expect(control.state == .idle)
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 0]) == false)
        _ = control.request(true)
        control.fail(.sendFailed)
        #expect(control.state == .failed(.sendFailed))
    }

    @Test func finishedRequestIsNotOverwrittenByTimeout() {
        var control = AdaptiveEQControl()
        _ = control.request(true)
        #expect(control.receiveAcknowledgement([MsgID.adaptiveEqualizerControl, 1]) == true)
        control.fail(.timedOut)
        #expect(control.state == .acknowledged(true))
    }
}
