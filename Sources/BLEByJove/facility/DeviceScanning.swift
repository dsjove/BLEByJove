//
//  DeviceScanning.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation

public protocol DeviceScanning: AnyObject {
	var scanning: Bool { get set }
	func anyDevices() -> [any DeviceIdentifiable]
}

public protocol DeviceScanner: DeviceScanning {
	associatedtype Device: DeviceIdentifiable
	var devices: [Device] { get }
}

public extension DeviceScanner {
	func anyDevices() -> [any DeviceIdentifiable] {
		devices.map { $0 as any DeviceIdentifiable }
	}
}


