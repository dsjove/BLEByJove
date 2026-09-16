import Foundation
import Observation

@MainActor
@Observable
public final class PFDevice<M: PFMeta>: DeviceIdentifiable, PFDeviceTransmitter {
    public nonisolated let id: UUID
    public let info: M
    private let transmitter: any PFTransmitter
    private var pinged: Date

    public init(info: M, transmitter: any PFTransmitter) {
        id = UUID(dataBytes: info.id)
        self.info = info
        self.transmitter = transmitter
        pinged = Date()
    }

    public var pfConnectionState: ConnectionState { transmitter.pfConnectionState }

    public func ping() {
        pinged = Date()
    }

    public func hasTimedOut(referenceDate: Date) -> Bool {
        guard !info.timeout.isZero else { return false }
        return referenceDate.timeIntervalSince(pinged) >= info.timeout
    }

    public func transmit(port: PFPort, power: Int8) {
        transmitter.transmit(cmd: PFCommand(channel: info.channel, port: port, power: power, mode: info.mode))
    }
}
