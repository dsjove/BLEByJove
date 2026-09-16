import Foundation
import Observation
import SBJFoundation

@MainActor
@Observable
public final class PFClient<M: PFMeta>: DeviceScanner, RFIDConsumer {
    private let meta: (SampledRFIDDetection) -> M?
    private let transmitter: any PFTransmitter
    private var timeoutTimer: Timer?

    public private(set) var devices: [PFDevice<M>] = []
    public var scanning = false

    public init(transmitter: any PFTransmitter, meta: @escaping (SampledRFIDDetection) -> M?) {
        self.meta = meta
        self.transmitter = transmitter

        let interval: TimeInterval = 10
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pruneTimedOutDevices()
            }
        }
    }

    isolated deinit {
        timeoutTimer?.invalidate()
    }

    public func consumeRFID(_ detection: SampledRFIDDetection) {
        guard scanning, !detection.rfid.id.isZero else { return }

        if let index = devices.firstIndex(where: { $0.info.id == detection.rfid.id }) {
            devices[index].ping()
        } else if let info = meta(detection) {
            devices.append(.init(info: info, transmitter: transmitter))
        }
    }

    private func pruneTimedOutDevices() {
        let now = Date()
        devices.removeAll { $0.hasTimedOut(referenceDate: now) }
    }
}
