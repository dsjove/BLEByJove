//
//  BTBroadcaster.swift
//  BLEByJove
//
//  Created by David Giovannini on 7/4/21.
//

import Foundation

public enum BTBroadcasterWriteResponse {
    case notSent
    case sentOnly
    case responseReceived
    case error(Error)

    /// Compatibility spelling retained for existing clients.
    @available(*, deprecated, renamed: "responseReceived")
    public static var reponseReceived: Self { .responseReceived }
}

/// Lightweight cancellation token for a broadcaster observation.
@MainActor
public final class BTSubscription {
    private var cancellation: (() -> Void)?

    public init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    public func cancel() {
        let cancellation = cancellation
        self.cancellation = nil
        cancellation?()
    }

    isolated deinit {
        cancel()
    }
}

/// UI-facing Bluetooth device access is main-actor isolated.
///
/// BLEByJove creates `CBCentralManager` with a nil queue, so CoreBluetooth central events are
/// delivered on the main queue. Keeping broadcaster state on `MainActor` makes that existing
/// threading model explicit to Swift concurrency instead of moving CoreBluetooth objects among
/// executors.
@MainActor
public protocol BTBroadcaster: AnyObject {
    func send(data: Data, to value: BTCharacteristicIdentity, confirmed: ((BTBroadcasterWriteResponse) -> Void)?)
    func request(value: BTCharacteristicIdentity)
    func read(value: BTCharacteristicIdentity) -> Data?
    func sink(id: UUID, to characteristic: BTCharacteristicIdentity, with: @escaping (Data) -> Void) -> BTSubscription
}

public extension BTBroadcaster {
    func send(data: Data, to value: BTCharacteristicIdentity) {
        send(data: data, to: value, confirmed: nil)
    }
}

@MainActor
public final class NullBTBroadcaster: BTBroadcaster {
    public init() {}

    public func send(data: Data, to value: BTCharacteristicIdentity, confirmed: ((BTBroadcasterWriteResponse) -> Void)?) {}
    public func request(value: BTCharacteristicIdentity) {}
    public func read(value: BTCharacteristicIdentity) -> Data? { nil }
    public func sink(id: UUID, to characteristic: BTCharacteristicIdentity, with: @escaping (Data) -> Void) -> BTSubscription {
        BTSubscription {}
    }
}
