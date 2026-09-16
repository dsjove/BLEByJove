import XCTest
@testable import BLEByJove

@MainActor
final class BTDeviceTests: XCTestCase {
    func testHardwareIndependentConnectionStateMachine() {
        var requests: [Bool] = []
        let device = BTDevice(
            name: "Test",
            deviceID: UUID(),
            service: BTServiceIdentity(name: "TestService"),
            makeConnection: { requests.append($0) }
        )

        XCTAssertEqual(device.connectionState, .disconnected)
        device.connect()
        XCTAssertEqual(device.connectionState, .connecting)
        XCTAssertEqual(requests, [true])

        device.peripheralConnected(nil)
        XCTAssertEqual(device.connectionState, .connected)

        device.disconnect()
        XCTAssertEqual(requests, [true, false])
        device.peripheralDisconnected(nil, nil)
        XCTAssertEqual(device.connectionState, .disconnected)
    }

    func testSendWithoutHardwareReportsNotSent() {
        let device = BTDevice(
            name: "Test",
            deviceID: UUID(),
            service: BTServiceIdentity(name: "TestService"),
            makeConnection: { _ in }
        )
        var response: BTBroadcasterWriteResponse?

        device.send(
            data: Data([0x01]),
            to: BTCharacteristicIdentity(),
            confirmed: { response = $0 }
        )

        guard case .notSent = response else {
            return XCTFail("Expected .notSent when no peripheral/characteristic exists")
        }
    }

    func testPreviewNameAndIdentity() {
        let id = UUID()
        let device = BTDevice(
            name: nil,
            deviceID: id,
            service: BTServiceIdentity(name: "Fallback"),
            makeConnection: { _ in }
        )
        XCTAssertEqual(device.id, id)
        XCTAssertEqual(device.name, "Fallback")
    }
}
