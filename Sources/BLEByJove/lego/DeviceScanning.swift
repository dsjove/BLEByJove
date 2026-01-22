//
//  DeviceScanning.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation

public protocol DeviceScanning: AnyObject {
	var scanning: Bool { get set }
	var anyDevices: [any DeviceIdentifiable] { get }
}

public protocol DeviceScanner: DeviceScanning {
	associatedtype Device: DeviceIdentifiable
	var devices: [Device] { get }
}

public extension DeviceScanner {
	var anyDevices: [any DeviceIdentifiable] {
		devices.map { $0 as any DeviceIdentifiable }
	}
}
