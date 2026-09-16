import XCTest
import Network
@testable import BLEByJove

final class PrimitivePackingTests: XCTestCase {
    func testStackedIntegersHaveStableLittleEndianWireBytes() throws {
        var data = Data()
        Int32(0x12345678).pack(btData: &data)
        UInt16(0x8765).pack(btData: &data)
        Bool(false).pack(btData: &data)
        Bool(true).pack(btData: &data)
        Int64(0x1234567890abcdef).pack(btData: &data)

        XCTAssertEqual(data, Data([
            0x78, 0x56, 0x34, 0x12,
            0x65, 0x87,
            0x00,
            0x01,
            0xEF, 0xCD, 0xAB, 0x90, 0x78, 0x56, 0x34, 0x12,
        ]))

        var cursor = 0
        XCTAssertEqual(0x12345678, try Int32(unpack: data, &cursor))
        XCTAssertEqual(0x8765, try UInt16(unpack: data, &cursor))
        XCTAssertFalse(try Bool(unpack: data, &cursor))
        XCTAssertTrue(try Bool(unpack: data, &cursor))
        XCTAssertEqual(0x1234567890abcdef, try Int64(unpack: data, &cursor))
        XCTAssertEqual(data.count, cursor)
    }

    func testIntegerUnpackSupportsUnalignedNonzeroCursor() throws {
        let data = Data([0xFF, 0x78, 0x56, 0x34, 0x12, 0xEE])
        var cursor = 1
        XCTAssertEqual(0x12345678, try UInt32(unpack: data, &cursor))
        XCTAssertEqual(5, cursor)
    }

    func testIntegerUnpackRejectsTruncatedDataAtCursor() {
        let data = Data([0x00, 0x78, 0x56, 0x34])
        var cursor = 1
        XCTAssertThrowsError(try UInt32(unpack: data, &cursor)) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidDataLength)
        }
        XCTAssertEqual(1, cursor)
    }

    func testIntegerUnpackRejectsCursorPastEnd() {
        var cursor = 2
        XCTAssertThrowsError(try UInt8(unpack: Data([0x01]), &cursor)) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidDataLength)
        }
    }

    func testBoolAcceptsAnyNonzeroWireByteAsTrue() throws {
        XCTAssertFalse(try Bool(unpack: Data([0])))
        XCTAssertTrue(try Bool(unpack: Data([1])))
        XCTAssertTrue(try Bool(unpack: Data([255])))
    }

    func testIPv4AddressExactBytesAndCursor() throws {
        let address = IPv4Address("192.168.4.1")!
        XCTAssertEqual(address.pack(), Data([192, 168, 4, 1]))

        let data = Data([0xAA, 192, 168, 4, 1, 0xBB])
        var cursor = 1
        let unpacked = try IPv4Address(unpack: data, &cursor)
        XCTAssertEqual(unpacked, address)
        XCTAssertEqual(cursor, 5)
    }

    func testIPv4AddressRejectsTruncation() {
        var cursor = 1
        XCTAssertThrowsError(try IPv4Address(unpack: Data([0, 127, 0, 0]), &cursor)) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidDataLength)
        }
    }
}
