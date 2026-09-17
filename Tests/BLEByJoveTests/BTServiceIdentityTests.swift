import XCTest
import CoreBluetooth
@testable import BLEByJove

private struct TestComponent: BTComponent { let rawValue: UInt8 }
private struct TestCategory: BTCategory { let rawValue: UInt8 }
private struct TestSubCategory: BTSubCategory { let rawValue: UInt8 }
private struct TestChannel: BTChannel { let rawValue: UInt8 }

final class BTServiceIdentityTests: XCTestCase {
    func testCharacteristicBytesAreStable() {
        let characteristic = BTCharacteristicIdentity(
            component: TestComponent(rawValue: 0x11),
            category: TestCategory(rawValue: 0x22),
            subCategory: TestSubCategory(rawValue: 0x33),
            channel: TestChannel(rawValue: 0x44)
        )
        let service = BTServiceIdentity(
            characteristic: characteristic,
            identifier: Data((0xA0...0xAB)),
            name: "Fixture"
        )

        let expectedServiceIdentifier = CBUUID(
            data: Data([0x11, 0x22, 0x33, 0x44]) + Data(0xA0...0xAB)
        )
        XCTAssertEqual(service.identifier, expectedServiceIdentifier)

        let changed = characteristic.apply(channel: TestChannel(rawValue: 0x99))
        let expectedChangedIdentifier = CBUUID(
            data: Data([0x11, 0x22, 0x33, 0x99]) + Data(0xA0...0xAB)
        )
        XCTAssertEqual(
            service.characteristic(characteristic: changed),
            expectedChangedIdentifier
        )
    }
}
