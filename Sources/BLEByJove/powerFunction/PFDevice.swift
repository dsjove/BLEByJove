import Foundation
import SBJKit

public class PFDevice: ObservableObject, DeviceIdentifiable {
	public let info: PFMeta
	public let id: UUID = UUID()
	public var name: String { info.name }
	public var image: ImageName { info.image }
	public let transmit: (PFCommand) -> Void
	public private(set) var pinged: Date

	public init(info: PFMeta, transmit: @escaping (PFCommand) -> Void) {
		self.info = info
		self.transmit = transmit
		self.pinged = Date()
	}

	public func ping() {
		self.pinged = Date()
	}

	public func hasTimedOut(referenceDate: Date) -> Bool {
		guard !info.timeout.isZero else { return false }
		let elapsed = referenceDate.timeIntervalSince(self.pinged)
		return elapsed >= info.timeout
	}

	func send(port: PFPort, power: UInt8) {
		let cmd = PFCommand(
			channel: info.channel, port: port, power: power, mode: info.mode)
		transmit(cmd)
	}
}

