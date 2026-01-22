import Foundation

@Observable
public class PFClient<M : PFMeta>: DeviceScanner, RFIDConsumer {
	private let meta: (SampledRFIDDetection)->M?
	private let transmitter: PFTransmitter
	private var timeoutTimer: Timer?

	public private(set) var devices: [PFDevice<M>] = []
	public var scanning: Bool = false

	public init(transmitter: PFTransmitter, meta: @escaping (SampledRFIDDetection)->M?) {
		self.meta = meta
		self.transmitter = transmitter

		let minTimeout: TimeInterval? = 10
		if let interval = minTimeout, interval > 0 {
			self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
				self?.pruneTimedOutDevices()
			}
		}
	}

	deinit {
		timeoutTimer?.invalidate()
	}

	public func consumeRFID(_ detection: SampledRFIDDetection) {
		guard scanning else { return }
		guard !detection.rfid.id.isZero else { return }
		if let index = devices.firstIndex(where: { $0.info.id == detection.rfid.id }) {
			devices[index].ping()
		}
		else if let info = meta(detection) {
			devices.append(.init(info: info, transmitter: transmitter))
		}
	}

	private func pruneTimedOutDevices() {
		let now = Date()
		devices.removeAll { device in
			device.hasTimedOut(referenceDate: now)
		}
	}
}
