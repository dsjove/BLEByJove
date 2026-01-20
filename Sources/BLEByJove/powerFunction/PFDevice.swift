import Foundation
import SBJKit

public class PFDevice: ObservableObject, DeviceIdentifiable {
	public let info: PFMeta
	public let id: UUID
	public var name: String { info.name }
	public var image: ImageName { info.image }
	public let transmitter: PFTransmitter
	public private(set) var pinged: Date

	public init(info: PFMeta, transmitter: PFTransmitter) {
		self.info = info
		self.id = info.uuid
		self.transmitter = transmitter
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

	public func send(port: PFPort, power: Int8) {
		let cmd = PFCommand(
			channel: info.channel, port: port, power: power, mode: info.mode)
		transmitter.transmit(cmd: cmd)
	}
}

