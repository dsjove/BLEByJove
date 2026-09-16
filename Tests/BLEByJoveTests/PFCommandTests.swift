import XCTest
@testable import BLEByJove

final class PFCommandTests: XCTestCase {
    func testExactWireFormat() throws {
        let command = PFCommand(channel: 2, port: .B, power: -50, mode: .single)
        XCTAssertEqual(command.pack(), Data([0x02, 0x01, 0xCE, 0x01]))
        XCTAssertEqual(command.packedSize, 4)
        XCTAssertEqual(try PFCommand(unpack: command.pack()), command)
    }

    func testBoundaryPowerValues() throws {
        for power in [Int8.min, -1, 0, 1, Int8.max] {
            let command = PFCommand(channel: 4, port: .A, power: power, mode: .combo)
            XCTAssertEqual(try PFCommand(unpack: command.pack()), command)
        }
    }

    func testEveryPortAndModeRoundTrips() throws {
        for port in PFPort.allCases {
            for mode in PFMode.allCases {
                let command = PFCommand(channel: 1, port: port, power: 7, mode: mode)
                XCTAssertEqual(try PFCommand(unpack: command.pack()), command)
            }
        }
    }

    func testInvalidPortRawValueIsRejected() {
        var cursor = 0
        XCTAssertThrowsError(try PFCommand(unpack: Data([1, 2, 0, 0]), &cursor)) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidRawValue)
        }
    }

    func testInvalidModeRawValueIsRejected() {
        var cursor = 0
        XCTAssertThrowsError(try PFCommand(unpack: Data([1, 0, 0, 2]), &cursor)) { error in
            XCTAssertEqual(error as? BTSerializeError, .invalidRawValue)
        }
    }

    func testEmbeddedAtNonzeroCursor() throws {
        let command = PFCommand(channel: 3, port: .B, power: 12, mode: .single)
        let data = Data([0xAA]) + command.pack() + Data([0xBB])
        var cursor = 1
        XCTAssertEqual(try PFCommand(unpack: data, &cursor), command)
        XCTAssertEqual(cursor, 5)
    }
}
