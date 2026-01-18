import Foundation
import Observation
import SBJKit

public struct FacilityCategory: Hashable, Sendable {
	let rawValue: String
	public init(_ rawValue: String) {
		self.rawValue = rawValue
	}
}

public protocol Facility: Identifiable {
	var id: UUID { get }

	var category: FacilityCategory { get }
	var name: String { get }
	var image: ImageName { get }

	var connectionState: ConnectionState { get }
	var heartBeat: Int { get }

	func connect()
	func fullStop()
	func disconnect()

	var battery: Double? { get }
}

public extension Facility {
	var heartBeat: Int { connectionState == .connected ? 0 : -1 }

	var battery: Double? { nil }
}
