import Testing
import os

@testable import Relente

struct HelperRequestReplyTests {

    @Test func `an immediate reply wins before the deadline`() async {
        let result = await withCheckedContinuation { continuation in
            let reply = HelperRequestReply(continuation)
            let timeout = reply.startTimeout(after: .seconds(5), operation: "test")
            if reply.finish(7) { timeout.cancel() }
        }

        #expect(result == 7)
    }

    @Test func `an unanswered request returns failure at its deadline`() async {
        let storedReply = OSAllocatedUnfairLock<HelperRequestReply?>(initialState: nil)
        let result = await withCheckedContinuation { continuation in
            let reply = HelperRequestReply(continuation)
            storedReply.withLock { $0 = reply }
            _ = reply.startTimeout(after: .milliseconds(20), operation: "test")
        }

        #expect(result == nil)
        #expect(storedReply.withLock { $0?.finish(42) } == false)
    }
}
