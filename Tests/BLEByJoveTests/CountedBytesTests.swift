import XCTest
@testable import BLEByJove

final class CountedBytesTests: XCTestCase {
    func testInitializerStoresPayloadNotWirePrefix() throws {
        let value = try CountedBytes(Data([0x10, 0x20, 0x30]))
        XCTAssertEqual(value.id, Data([0x10, 0x20, 0x30]))
        XCTAssertEqual(value.packedSize, 4)
        XCTAssertEqual(value.pack(), Data([0x03, 0x10, 0x20, 0x30]))
    }

    func testEmptyPayload() throws {
        let value = try CountedBytes(Data())
        XCTAssertEqual(value.pack(), Data([0]))
        XCTAssertEqual(try CountedBytes(unpack: value.pack()), value)
    }

    func testMaximumPayload() throws {
        let payload = Data((0...254).map(UInt8.init))
        let value = try CountedBytes(payload)
        let packed = value.pack()
        XCTAssertEqual(packed.count, 256)
        XCTAssertEqual(packed.first, 255)
        XCTAssertEqual(try CountedBytes(unpack: packed).id, payload)
    }

    func testPayloadOver255BytesIsRejected() {
        XCTAssertThrowsError(try CountedBytes(Data(repeating: 0xAA, count: 256))) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidDataLength)
        }
    }

    func testUnpackAtNonzeroCursor() throws {
        let data = Data([0xEE, 0x03, 0x01, 0x02, 0x03, 0xFF])
        var cursor = 1
        let value = try CountedBytes(unpack: data, &cursor)
        XCTAssertEqual(value.id, Data([1, 2, 3]))
        XCTAssertEqual(cursor, 5)
    }

    func testTruncatedPayloadIsRejectedWithoutAdvancingPastPayloadStart() {
        var cursor = 0
        XCTAssertThrowsError(try CountedBytes(unpack: Data([3, 1, 2]), &cursor)) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidDataLength)
        }
        XCTAssertEqual(cursor, 1)
    }
}
