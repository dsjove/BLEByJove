import XCTest
@testable import BLEByJove

@MainActor
final class BTUARTTests: XCTestCase {
    private let tx = BTCharacteristicIdentity(channel: BTUARTChannel.tx)
    private let rx = BTCharacteristicIdentity(channel: BTUARTChannel.rx)

    func testOnlyCurrentRequestIsSentAndResponsesAdvanceFIFO() {
        let broadcaster = TestBroadcaster()
        let uart = BTUART(tx, rx, broadcaster)
        uart.connect()

        var responses: [Data?] = []
        uart.call(Data([1]), timeout: 1_000) { responses.append($0) }
        uart.call(Data([2]), timeout: 1_000) { responses.append($0) }

        XCTAssertEqual(broadcaster.sent.map(\.data), [Data([1])])
        broadcaster.emit(Data([0xA1]), on: rx)
        XCTAssertEqual(responses, [Data([0xA1])])
        XCTAssertEqual(broadcaster.sent.map(\.data), [Data([1]), Data([2])])

        broadcaster.emit(Data([0xA2]), on: rx)
        XCTAssertEqual(responses, [Data([0xA1]), Data([0xA2])])
    }

    func testQueuedDropKeyCoalescesToNewestWithoutReplacingActiveRequest() {
        let broadcaster = TestBroadcaster()
        let uart = BTUART(tx, rx, broadcaster)
        uart.connect()

        var active: Data?
        var replaced: Data??
        var newest: Data?

        uart.call(Data([1]), timeout: 1_000, dropKey: "motor") { active = $0 }
        uart.call(Data([2]), timeout: 1_000, dropKey: "motor") { replaced = .some($0) }
        uart.call(Data([3]), timeout: 1_000, dropKey: "motor") { newest = $0 }

        XCTAssertEqual(broadcaster.sent.map(\.data), [Data([1])])
        XCTAssertNotNil(replaced)
        XCTAssertNil(replaced!)

        broadcaster.emit(Data([0xA1]), on: rx)
        XCTAssertEqual(active, Data([0xA1]))
        XCTAssertEqual(broadcaster.sent.map(\.data), [Data([1]), Data([3])])

        broadcaster.emit(Data([0xA3]), on: rx)
        XCTAssertEqual(newest, Data([0xA3]))
    }

    func testTimeoutAdvancesQueueAndOldTimeoutCannotExpireNextRequest() async throws {
        let broadcaster = TestBroadcaster()
        let uart = BTUART(tx, rx, broadcaster)
        uart.connect()

        var firstCompleted = false
        var second: Data?
        uart.call(Data([1]), timeout: 20, response: { data in
            XCTAssertNil(data)
            firstCompleted = true
        })
        uart.call(Data([2]), timeout: 500, response: { second = $0 })

        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(firstCompleted)
        XCTAssertEqual(broadcaster.sent.map(\.data), [Data([1]), Data([2])])

        broadcaster.emit(Data([0x22]), on: rx)
        XCTAssertEqual(second, Data([0x22]))
    }

    func testDisconnectFailsPendingRequestsAndStopsObservation() {
        let broadcaster = TestBroadcaster()
        let uart = BTUART(tx, rx, broadcaster)
        uart.connect()

        var completions = 0
        uart.call(Data([1]), timeout: 1_000) { data in
            XCTAssertNil(data)
            completions += 1
        }
        uart.call(Data([2]), timeout: 1_000) { data in
            XCTAssertNil(data)
            completions += 1
        }

        uart.disconnect()
        XCTAssertEqual(completions, 2)
        broadcaster.emit(Data([0xFF]), on: rx)
        XCTAssertEqual(completions, 2)
    }

    func testAsyncParseCall() async {
        let broadcaster = TestBroadcaster()
        let uart = BTUART(tx, rx, broadcaster)
        uart.connect()

        let task = Task { @MainActor in
            await uart.call(Data([0x10]), timeout: 1_000) { data in
                data.first.map(Int.init)
            }
        }

        await Task.yield()
        broadcaster.emit(Data([0x42]), on: rx)
        let r = await task.value
        XCTAssertEqual(r, 0x42)
    }
}
