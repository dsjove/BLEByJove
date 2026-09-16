//
//  BTScanner.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import CoreBluetooth

@MainActor
public protocol BTScannerDelegate: AnyObject {
    func peripheralDiscovered(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber)
    func peripheralConnected(_ peripheral: CBPeripheral)
    func peripheralConnectFailed(_ peripheral: CBPeripheral, _ error: Error?)
    func peripheralDisconnected(_ peripheral: CBPeripheral, _ error: Error?)
}

extension CBManagerAuthorization {
    var canStartScan: Bool {
        switch self {
        case .notDetermined, .allowedAlways:
            true
        case .restricted, .denied:
            false
        @unknown default:
            false
        }
    }
}

/// Owns the raw CoreBluetooth central-manager lifecycle.
///
/// This remains separate from `BTClient` intentionally: `BTScanner` is the CoreBluetooth boundary,
/// while `BTClient` recognizes supported services and owns `BTDevice` instances. The separation
/// also provides a narrow seam for testing higher-level discovery behavior without BLE hardware.
@MainActor
public final class BTScanner: NSObject {
    private let centralManager: CBCentralManager
    private var wantedServices: [BTServiceIdentity]?
    private var isScanning = false

    public weak var delegate: BTScannerDelegate?

    public override init() {
        // A nil queue asks CoreBluetooth to deliver central-manager events on the main queue.
        // Keep this in sync with the @MainActor isolation used throughout the BLE object graph.
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        centralManager.delegate = self
    }

    // Do not touch `centralManager` from `deinit`: Swift deinitializers are nonisolated by
    // default, while CoreBluetooth objects are intentionally confined to the main actor here.
    // Scanner owners stop explicitly when needed; deallocation releases the central manager.

    public var authorization: CBManagerAuthorization {
        CBCentralManager.authorization
    }

    public func startScan(services: [BTServiceIdentity]) {
        wantedServices = services
        guard authorization.canStartScan, centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: services.isEmpty ? nil : services.map(\.identifier)
        )
    }

    public func stopScan() {
        wantedServices = nil
        guard isScanning else { return }
        isScanning = false
        centralManager.stopScan()
    }

    public func connect(device: CBPeripheral) {
        centralManager.connect(device, options: nil)
    }

    public func disconnect(device: CBPeripheral) {
        centralManager.cancelPeripheralConnection(device)
    }
}

extension BTScanner: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .resetting, .unsupported, .unauthorized, .poweredOff:
            isScanning = false
        case .poweredOn:
            if let wantedServices, !isScanning {
                startScan(services: wantedServices)
            }
        case .unknown:
            break
        @unknown default:
            isScanning = false
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        delegate?.peripheralDiscovered(peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.peripheralConnected(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.peripheralConnectFailed(peripheral, error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        delegate?.peripheralDisconnected(peripheral, error)
    }
}
