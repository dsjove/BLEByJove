import Foundation
@testable import BLEByJove

@MainActor
final class TestBroadcaster: BTBroadcaster {
    struct Sent: Equatable {
        let data: Data
        let characteristic: BTCharacteristicIdentity
    }

    private var observers: [UUID: (BTCharacteristicIdentity, (Data) -> Void)] = [:]
    private var reads: [BTCharacteristicIdentity: Data] = [:]
    private(set) var sent: [Sent] = []

    func send(data: Data, to value: BTCharacteristicIdentity, confirmed: ((BTBroadcasterWriteResponse) -> Void)?) {
        sent.append(.init(data: data, characteristic: value))
        confirmed?(.sentOnly)
    }

    func request(value: BTCharacteristicIdentity) {}

    func read(value: BTCharacteristicIdentity) -> Data? {
        reads[value]
    }

    func sink(id: UUID, to characteristic: BTCharacteristicIdentity, with: @escaping (Data) -> Void) -> BTSubscription {
        observers[id] = (characteristic, with)
        return BTSubscription { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setRead(_ data: Data?, for characteristic: BTCharacteristicIdentity) {
        reads[characteristic] = data
    }

    func emit(_ data: Data, on characteristic: BTCharacteristicIdentity) {
        for observation in observers.values where observation.0 == characteristic {
            observation.1(data)
        }
    }
}
