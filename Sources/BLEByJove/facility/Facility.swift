import Foundation
import Observation
import SBJKit

public struct FacilityCategory: Hashable, Sendable {
	let rawValue: String
	public init(_ rawValue: String) {
		self.rawValue = rawValue
	}
}

public protocol HardwareConnecting {
	var hasConnectionState: Bool { get }
	var connectionState: ConnectionState { get }
	func connect()
	func disconnect()

	var heartBeat: Int { get }
	func fullStop()
}

public extension Facility {
	var hasConnectionState: Bool { true }
	var heartBeat: Int { connectionState == .connected ? 0 : -1 }
}

public protocol Facility: HardwareConnecting, Identifiable {
	var id: UUID { get }

	var category: FacilityCategory { get }
	var name: String { get }
	var image: ImageName { get }

	var canSetName: Bool { get }
	func change(name: String)

	var battery: Double? { get }
}

public extension Facility {
	var canSetName: Bool { false }
	func change(name: String) {}
	var battery: Double? { nil }
}
