import XCTest
@testable import BLEByJove

@MainActor
final class RFIDProducerTests: XCTestCase {
    func testKnownWorkingReaderSamplingSemantics() {
        let producer = RFIDProducer(
            device: NullBTBroadcaster(),
            noiseThresholdMS: 3_000,
            silenceThresholdSecs: 0
        )
        let id = Data([1, 2, 3, 4])

        producer.receive(.init(reader: 1, timeStampMS: 1_000, id: id))
        XCTAssertEqual(producer.currentRFID?.count, 1)
        XCTAssertEqual(producer.currentRFID?.anotherRound, true)

        producer.receive(.init(reader: 1, timeStampMS: 2_000, id: id))
        XCTAssertEqual(producer.currentRFID?.count, 1)
        XCTAssertEqual(producer.currentRFID?.anotherRound, false)

        producer.receive(.init(reader: 1, timeStampMS: 5_500, id: id))
        XCTAssertEqual(producer.currentRFID?.count, 2)
        XCTAssertEqual(producer.currentRFID?.anotherRound, true)
    }

    func testZeroRFIDAndResetClearCurrentDetection() {
        let producer = RFIDProducer(
            device: NullBTBroadcaster(),
            silenceThresholdSecs: 0
        )

        producer.receive(.init(reader: 1, timeStampMS: 1, id: Data([1])))
        XCTAssertNotNil(producer.currentRFID)

        producer.receive(.init(reader: 1, timeStampMS: 2, id: Data([0, 0])))
        XCTAssertNil(producer.currentRFID)

        producer.receive(.init(reader: 1, timeStampMS: 3, id: Data([2])))
        producer.resetRFID()
        XCTAssertNil(producer.currentRFID)
    }
}
