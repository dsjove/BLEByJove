import Foundation

@Observable
public class PFClient: DeviceScanner, RFIDConsumer {
	private let meta: (RFIDDetection)->PFMeta?
	private let transmitter: PFTransmitter
	private var timeoutTimer: Timer?

	public private(set) var devices: [PFDevice] = []
	public var scanning: Bool = false

	public init(meta: @escaping (RFIDDetection)->PFMeta?, transmitter: PFTransmitter) {
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

	public func didDetectRFID(_ detection: RFIDDetection) {
		guard scanning else { return }
		guard !detection.id.isZero else { return }
		if let index = devices.firstIndex(where: { $0.info.id == detection.id.id }) {
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
