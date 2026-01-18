import Foundation

@Observable
public class PFClient: DeviceScanner {
	private let knownDevices: [Data: PFMeta]
	private let transmit: (PFCommand) -> Void
	private var timeoutTimer: Timer?

	public private(set) var devices: [PFDevice] = []
	public var scanning: Bool = false

	public init(knownDevices: [PFMeta], transmit: @escaping (PFCommand) -> Void) {
		self.knownDevices = Dictionary(uniqueKeysWithValues: knownDevices.map { ($0.id, $0) })
		self.transmit = transmit

		let minTimeout = self.knownDevices.values.compactMap { $0.timeout }.min()
		if let interval = minTimeout, interval > 0 {
			self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
				self?.pruneTimedOutDevices()
			}
		}
	}

	deinit {
		timeoutTimer?.invalidate()
	}

	public func detected(id: Data) -> Bool {
		guard !scanning else { return false }
		if let index = devices.firstIndex(where: { $0.info.id == id }) {
			devices[index].ping()
			return true
		}
		else if let info = knownDevices[id] {
			devices.append(.init(info: info, transmit: transmit))
			return true
		}
		return false
	}

	private func pruneTimedOutDevices() {
		let now = Date()
		devices.removeAll { device in
			device.hasTimedOut(referenceDate: now)
		}
	}
}

extension PFClient: RFIDConsumer {
	public func didDetectRFID(_ detection: RFIDDetection) {
		detected(id: detection.id.id)
	}
}

public protocol PowerFunctionsRemote {
	func transmit(cmd: PFCommand)
}

extension FacilityRepository: PowerFunctionsRemote {
	public func transmit(cmd: PFCommand) {
		facilities
			.lazy
			.compactMap { $0 as? PowerFunctionsRemote }
			.first?.transmit(cmd: cmd)
	}
}
