//
//  BTClient.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import Combine
import CoreBluetooth

public final class BTClient: ObservableObject {
	private let scanner: BTScanner
	private let services: [BTServiceIdentity]
	private var mocking: [BTDevice] = []
	
	private var known: [UUID: BTDevice] = [:] {
		didSet {
			self.devices = self.known.values.sorted {
				$0.name < $1.name
			}
		}
	}
	
	@Published public private(set) var devices: [BTDevice] = []
	
	public init(services: [BTServiceIdentity], mocking: Bool = false) {
		self.scanner = BTScanner()
		self.services = services
		scanner.delegate = self
		self.mocking = !mocking ? [] : self.services.map {
			let id = UUID()
			return BTDevice(name: nil, deviceID: id, service: $0) {
				if $0 {
					self.known[id]?.peripheralConnected(nil)
				}
				else {
					self.known[id]?.peripheralDisconnected(nil, nil)
				}
			}
		}
	}
	
	@Published public var scanning: Bool = false {
		didSet {
			if scanning {
				self.scanner.startScan(services: services)
				for mock in mocking {
					let existing = self.known[mock.id]
					if existing == nil {
						self.known[mock.id] = mock
					}
				}
			}
			else {
				self.scanner.stopScan()
			}
		}
	}

	public func removeDevice(_ device: BTDevice) {
		device.disconnect()
		known.removeValue(forKey: device.id)
	}
}

extension BTClient: BTScannerDelegate {
	public func peripheralDiscovered(_ peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		let existing = self.known[peripheral.identifier]
		if existing == nil {
			let device = self.create(peripheral, advertisementData)
			self.known[peripheral.identifier] = device
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
