//
//  BTClient.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import CoreBluetooth

@Observable
public final class BTClient: DeviceScanner {
	private let scanner: BTScanner
	private let services: [BTServiceIdentity]

	private var known: [UUID: BTDevice] = [:]

	public private(set) var devices: [BTDevice] = []
	
	private func publishDevices() {
		self.devices = self.known.values.sorted { $0.name < $1.name }
	}

	private func upsertKnown(_ device: BTDevice, for id: UUID) {
		self.known[id] = device
		self.publishDevices()
	}

	private func removeKnown(for id: UUID) {
		self.known.removeValue(forKey: id)
		self.publishDevices()
	}
	
	public init(services: [BTServiceIdentity]) {
		self.scanner = BTScanner()
		self.services = services
		scanner.delegate = self
	}
	
	public var scanning: Bool = false {
		didSet {
			if scanning {
				self.scanner.startScan(services: services)
			}
			else {
				self.scanner.stopScan()
			}
		}
	}

	public func removeDevice(_ device: BTDevice) {
		device.disconnect()
		removeKnown(for: device.id)
	}
}

extension BTClient: BTScannerDelegate {
	public func peripheralDiscovered(_ peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		let existing = self.known[peripheral.identifier]
		if existing == nil, let device = self.create(peripheral, advertisementData) {
			self.upsertKnown(device, for: peripheral.identifier)
		}
	}

	private func create(_ peripheral: CBPeripheral, _ advertisementData: [String : Any]) -> BTDevice? {
		let serviceID = (advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID])?.first
		let service = services.first { $0.identifer == serviceID }
		if let service {
			let scanner = self.scanner
			return BTDevice(peripheral: peripheral, advertisementData: advertisementData, service: service) {
				if $0 {
					scanner.connect(device: peripheral)
				}
				else {
					scanner.disconnect(device: peripheral)
				}
			}
		}
		return nil
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
