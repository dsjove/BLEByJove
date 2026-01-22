import Foundation
import BLEByJove

public struct PFBTRransmitter: PFTransmitter {
	let device: BTDevice
	let characteristic: BTCharacteristicIdentity

	// The BLE device needs to transform power if using Int8 min/max
	// 0 = float
	// 1..7 = fwd1..fwd7
	// 8 = brake
	// 9..15 = rev7..rev1
	static let coast: Int8 = -128
	static let brake: Int8 = 0

	public init(
			device: BTDevice,
			component: BTComponent = EmptyComponent(),
			category: BTCategory = EmptyCategory(),
			subCategory: BTSubCategory = EmptySubCategory()) {
		self.device = device
		self.characteristic = .init(
				component: component,
				category: category,
				subCategory: subCategory)
	}

	public func transmit(cmd: PFCommand) {
		device.send(data: cmd.pack(), to: characteristic)
	}
	
	public var pfConnectionState: ConnectionState {
		device.connectionState
	}
}
