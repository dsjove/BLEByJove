import Foundation
import SBJKit

public class PFDevice<M: PFMeta>: ObservableObject, DeviceIdentifiable, PFDeviceTransmitter {
	public let id: UUID
	public let info: M
	private let transmitter: PFTransmitter
	private private(set) var pinged: Date

	public init(info: M, transmitter: PFTransmitter) {
		self.id = info.uuid
		self.info = info
		self.transmitter = transmitter
		self.pinged = Date()
	}

	public var pfConnectionState: ConnectionState {
		transmitter.pfConnectionState
	}

	public func ping() {
		self.pinged = Date()
	}

	public func hasTimedOut(referenceDate: Date) -> Bool {
		guard !info.timeout.isZero else { return false }
		let elapsed = referenceDate.timeIntervalSince(self.pinged)
		return elapsed >= info.timeout
	}

	public func transmit(port: PFPort, power: Int8) {
		let cmd = PFCommand(
			channel: info.channel, port: port, power: power, mode: info.mode)
		transmitter.transmit(cmd: cmd)
	}
}
