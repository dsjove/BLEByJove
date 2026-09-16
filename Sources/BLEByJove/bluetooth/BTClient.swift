//
//  BTClient.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
public final class BTClient: DeviceScanner {
    private let scanner: BTScanner
    private let services: [BTServiceIdentity]
    private var known: [UUID: BTDevice] = [:]

    public private(set) var devices: [BTDevice] = []

    public init(services: [BTServiceIdentity]) {
        scanner = BTScanner()
        self.services = services
        scanner.delegate = self
    }

    public var scanning = false {
        didSet {
            scanning ? scanner.startScan(services: services) : scanner.stopScan()
        }
    }

    public func removeDevice(_ device: BTDevice) {
        device.disconnect()
        known.removeValue(forKey: device.id)
        publishDevices()
    }

    private func publishDevices() {
        devices = known.values.sorted { $0.name < $1.name }
    }

    private func upsertKnown(_ device: BTDevice, for id: UUID) {
        known[id] = device
        publishDevices()
    }

    private func create(_ peripheral: CBPeripheral, _ advertisementData: [String: Any]) -> BTDevice? {
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        guard let service = services.first(where: { advertisedServices?.contains($0.identifier) == true }) else {
            return nil
        }

        let scanner = scanner
        return BTDevice(peripheral: peripheral, advertisementData: advertisementData, service: service) { shouldConnect in
            shouldConnect ? scanner.connect(device: peripheral) : scanner.disconnect(device: peripheral)
        }
    }
}

extension BTClient: BTScannerDelegate {
    public func peripheralDiscovered(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard known[peripheral.identifier] == nil,
              let device = create(peripheral, advertisementData) else { return }
        upsertKnown(device, for: peripheral.identifier)
    }

    public func peripheralConnected(_ peripheral: CBPeripheral) {
        known[peripheral.identifier]?.peripheralConnected(peripheral)
    }

    public func peripheralConnectFailed(_ peripheral: CBPeripheral, _ error: Error?) {
        known[peripheral.identifier]?.peripheralConnectFailed(peripheral, error)
    }

    public func peripheralDisconnected(_ peripheral: CBPeripheral, _ error: Error?) {
        known[peripheral.identifier]?.peripheralDisconnected(peripheral, error)
    }
}
