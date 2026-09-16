//
//  BTDevice.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
public class BTDevice: NSObject, DeviceIdentifiable, BTBroadcaster {
    private let peripheral: CBPeripheral?
    private let makeConnection: (Bool) -> Void

    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var notifyActivating: Set<CBUUID> = []
    private var distribute: [UUID: [CBUUID: (Data) -> Void]] = [:]
    private var cachedWrites: [BTCharacteristicIdentity: (Data, ((BTBroadcasterWriteResponse) -> Void)?)] = [:]
    private var confirmingWrites: [CBUUID: [(BTBroadcasterWriteResponse) -> Void]] = [:]
    private var connected = false {
        didSet {
            if oldValue != connected {
                connectionState = connected ? .connected : .disconnected
            }
        }
    }

    public private(set) var connectionState: ConnectionState = .disconnected
    public var name: String

    public let service: BTServiceIdentity
    public nonisolated let id: UUID

    public init(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        service: BTServiceIdentity,
        makeConnection: @escaping (Bool) -> Void
    ) {
        id = peripheral.identifier
        self.peripheral = peripheral
        self.service = service
        self.makeConnection = makeConnection
        name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? service.name
        super.init()
        peripheral.delegate = self
    }

    /// Hardware-independent initializer used by previews and unit tests.
    public init(
        name: String?,
        deviceID: UUID,
        service: BTServiceIdentity,
        makeConnection: @escaping (Bool) -> Void
    ) {
        id = deviceID
        peripheral = nil
        self.service = service
        self.makeConnection = makeConnection
        self.name = name ?? service.name
        super.init()
    }

    public convenience init(preview: String) {
        self.init(
            name: preview,
            deviceID: UUID(),
            service: BTServiceIdentity(name: preview),
            makeConnection: { _ in }
        )
    }

    public func connect() {
        guard !connected else { return }
        notifyActivating.removeAll()
        connectionState = .connecting
        makeConnection(true)
    }

    public func disconnect() {
        guard connected || connectionState == .connecting else { return }
        notifyActivating.removeAll()
        makeConnection(false)
    }

    public func send(data: Data, to value: BTCharacteristicIdentity, confirmed: ((BTBroadcasterWriteResponse) -> Void)?) {
        let identity = service.characteristic(characteristic: value)
        guard let peripheral, let characteristic = characteristics[identity] else {
            confirmed?(.notSent)
            return
        }

        if let confirmed, characteristic.properties.contains(.write) {
            confirmingWrites[identity, default: []].append(confirmed)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            return
        }

        let old = cachedWrites.removeValue(forKey: value)
        old?.1?(.notSent)

        guard peripheral.canSendWriteWithoutResponse else {
            cachedWrites[value] = (data, confirmed)
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        confirmed?(.sentOnly)
    }

    public func read(value: BTCharacteristicIdentity) -> Data? {
        characteristics[service.characteristic(characteristic: value)]?.value
    }

    public func request(value: BTCharacteristicIdentity) {
        let identity = service.characteristic(characteristic: value)
        guard let peripheral, let characteristic = characteristics[identity] else { return }
        peripheral.readValue(for: characteristic)
    }

    public func sink(
        id: UUID,
        to characteristic: BTCharacteristicIdentity,
        with receive: @escaping (Data) -> Void
    ) -> BTSubscription {
        let identifier = service.characteristic(characteristic: characteristic)
        distribute[id, default: [:]][identifier] = receive

        if let cb = characteristics[identifier],
           cb.properties.contains(.notify),
           let peripheral,
           !notifyActivating.contains(identifier) {
            notifyActivating.insert(identifier)
            peripheral.setNotifyValue(true, for: cb)
        }

        return BTSubscription { [weak self] in
            self?.distribute.removeValue(forKey: id)
        }
    }

    public func peripheralConnected(_ peripheral: CBPeripheral?) {
        if let peripheral {
            peripheral.discoverServices([service.identifier])
        } else {
            connected = true
        }
    }

    public func peripheralConnectFailed(_ peripheral: CBPeripheral?, _ error: Error?) {
        connected = false
    }

    public func peripheralDisconnected(_ peripheral: CBPeripheral?, _ error: Error?) {
        cachedWrites.forEach { $0.value.1?(.notSent) }
        cachedWrites.removeAll()
        confirmingWrites.values.flatMap { $0 }.forEach { $0(.notSent) }
        confirmingWrites.removeAll()
        characteristics.removeAll()
        notifyActivating.removeAll()
        connected = false
    }

    private func distribute(_ data: Data, for characteristic: CBCharacteristic) {
        let identifier = characteristic.uuid
        for routes in distribute.values {
            routes[identifier]?(data)
        }
    }
}

extension BTDevice: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            connected = false
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            connected = false
            return
        }

        for characteristic in service.characteristics ?? [] {
            let identity = characteristic.uuid
            characteristics[identity] = characteristic

            if let data = characteristic.value, !data.isEmpty {
                distribute(data, for: characteristic)
            }

            if characteristic.properties.contains(.notify),
               !notifyActivating.contains(identity),
               distribute.values.contains(where: { $0[identity] != nil }) {
                notifyActivating.insert(identity)
                peripheral.setNotifyValue(true, for: characteristic)
            }

            peripheral.discoverDescriptors(for: characteristic)
        }
        connected = true
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {}

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.isNotifying else { return }
        if characteristic.value?.isEmpty ?? true, characteristic.properties.contains(.read) {
            peripheral.readValue(for: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }
        distribute(data, for: characteristic)
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        let values = cachedWrites
        cachedWrites.removeAll()
        for (identity, value) in values {
            send(data: value.0, to: identity, confirmed: value.1)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard var completions = confirmingWrites[characteristic.uuid], !completions.isEmpty else { return }
        let completion = completions.removeFirst()
        if completions.isEmpty {
            confirmingWrites.removeValue(forKey: characteristic.uuid)
        } else {
            confirmingWrites[characteristic.uuid] = completions
        }

        if let error {
            completion(.error(error))
        } else {
            completion(.responseReceived)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // CoreBluetooth will rediscover invalidated services as needed. Remove stale characteristic
        // references immediately so writes cannot target objects belonging to an invalid service.
        let invalidated = Set(invalidatedServices.flatMap { $0.characteristics ?? [] }.map(\.uuid))
        characteristics = characteristics.filter { !invalidated.contains($0.key) }
        notifyActivating.subtract(invalidated)
    }
}
