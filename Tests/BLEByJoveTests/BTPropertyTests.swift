import XCTest
@testable import BLEByJove

@MainActor
final class BTPropertyTests: XCTestCase {
    func testControlUsesStableSerializationAndFeedbackUnpacks() {
        let broadcaster = TestBroadcaster()
        let characteristic = BTCharacteristicIdentity(channel: BTPropChannel.feedback)
        let property = BTProperty(
            broadcaster: broadcaster,
            characteristic: characteristic,
            transfomer: BTValueTransformer<UInt16>(),
            defaultValue: 0
        )

        property.control = 0x1234
        XCTAssertEqual(broadcaster.sent.last?.data, Data([0x34, 0x12]))

        broadcaster.emit(Data([0xCD, 0xAB]), on: characteristic)
        XCTAssertEqual(property.feedback, 0xABCD)
    }

    func testInitialReadSeedsFeedback() {
        let broadcaster = TestBroadcaster()
        let characteristic = BTCharacteristicIdentity(channel: BTPropChannel.feedback)
        broadcaster.setRead(Data([0x78, 0x56]), for: characteristic)

        let property = BTProperty(
            broadcaster: broadcaster,
            characteristic: characteristic,
            transfomer: BTValueTransformer<UInt16>(),
            defaultValue: 0
        )

        XCTAssertEqual(property.feedback, 0x5678)
    }
}
