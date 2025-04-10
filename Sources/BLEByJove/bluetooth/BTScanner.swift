//
//  BTScanner.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import Combine
import CoreBluetooth

public protocol BTScannerDelegate: AnyObject {
	func peripheralDiscovered(_ peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
	func peripheralConnected(_ peripheral: CBPeripheral)
	func peripheralConnectFailed(_ peripheral: CBPeripheral, _ error: Error?)
	func peripheralDisconnected(_ peripheral: CBPeripheral, _ error: Error?)
}

extension CBManagerAuthorization {
	var canStartScan: Bool {
		switch self {
		case .notDetermined:
			return true
		case .restricted:
			return false
		case .denied:
			return false
		case .allowedAlways:
			return true
		@unknown default:
			return false
		}
	}
}

// Invocations are expected on the main thread
public final class BTScanner: NSObject {
	private let centralManager : CBCentralManager
	private var wantScan: [BTServiceIdentity]?
	private var scanning: Bool = false
	
	// delegate calls happen on the main thread
	public weak var delegate: BTScannerDelegate?

	public override init() {
		centralManager = CBCentralManager(delegate: nil, queue: nil)
		super.init()
		centralManager.delegate = self
	}
	
	deinit {
		centralManager.stopScan()
	}
	
	public var authorization: CBManagerAuthorization {
		CBCentralManager.authorization
	}
	
	public func startScan(services: [BTServiceIdentity]) {
		self.wantScan = services
		if authorization.canStartScan && centralManager.state == .poweredOn {
			if !self.scanning {
				self.scanning = true
			}
			centralManager.scanForPeripherals(withServices: services.count == 0 ? nil : services.map(\.identifer))
		}
	}
	
	public func stopScan() {
		self.wantScan = nil
		if self.scanning {
			self.scanning = false
			centralManager.stopScan()
		}
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
		case .unknown:
			break
		case .resetting:
			self.scanning = false
		case .unsupported:
			self.scanning = false
		case .unauthorized:
			self.scanning = false
		case .poweredOff:
			self.scanning = false
		case .poweredOn:
			if let wantScan = self.wantScan, !self.scanning {
				self.startScan(services: wantScan)
			}
			break
		@unknown default:
			break
		}
	}
	
	public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {

		//let serviceIDs = advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID]
		//let name = advertisementData["kCBAdvDataLocalName"] as? String
		//print("\(peripheral.identifier) \(serviceIDs) \(name ?? peripheral.name)")

		self.delegate?.peripheralDiscovered(peripheral, advertisementData: advertisementData, rssi: RSSI)
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
