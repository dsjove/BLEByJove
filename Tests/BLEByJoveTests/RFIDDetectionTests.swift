import XCTest
@testable import BLEByJove

final class RFIDDetectionTests: XCTestCase {
    func testKnownWorkingReaderWireFormat() throws {
        let detection = RFIDDetection(
            reader: 0x11223344,
            timeStampMS: 0xAABBCCDD,
            id: Data([0xDE, 0xAD, 0xBE])
        )
        let expected = Data([
            0x44, 0x33, 0x22, 0x11,
            0xDD, 0xCC, 0xBB, 0xAA,
            0x03, 0xDE, 0xAD, 0xBE,
        ])

        XCTAssertEqual(detection.pack(), expected)
        XCTAssertEqual(detection.packedSize, expected.count)
        XCTAssertEqual(try RFIDDetection(unpack: expected), detection)
    }

    func testEmptyRFIDRoundTrips() throws {
        let detection = RFIDDetection(reader: 1, timeStampMS: 2, id: Data())
        XCTAssertEqual(detection.pack(), Data([1, 0, 0, 0, 2, 0, 0, 0, 0]))
        XCTAssertEqual(try RFIDDetection(unpack: detection.pack()), detection)
    }

    func testEmbeddedAtNonzeroCursor() throws {
        let detection = RFIDDetection(reader: 9, timeStampMS: 42, id: Data([1, 2, 3, 4]))
        let data = Data([0xAA, 0xBB]) + detection.pack() + Data([0xCC])
        var cursor = 2
        XCTAssertEqual(try RFIDDetection(unpack: data, &cursor), detection)
        XCTAssertEqual(cursor, 2 + detection.packedSize)
    }

    func testTruncatedReaderIsRejected() {
        XCTAssertThrowsError(try RFIDDetection(unpack: Data([1, 2, 3])))
    }

    func testTruncatedTimestampIsRejected() {
        XCTAssertThrowsError(try RFIDDetection(unpack: Data([1, 0, 0, 0, 1, 2, 3])))
    }

    func testTruncatedCountedRFIDIsRejected() {
        XCTAssertThrowsError(try RFIDDetection(unpack: Data([
            1, 0, 0, 0,
            2, 0, 0, 0,
            3, 0xAA, 0xBB,
        ])))
    }
}
