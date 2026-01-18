//
//  DeviceScanning.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation

public protocol DeviceScanning: AnyObject {
	var scanning: Bool { get set }
}

protocol DeviceScanning2: DeviceScanning {
	func snapshotDevices() -> [any DeviceIdentifiable]
	func startObservingDevices(onChange: @escaping () -> Void)
}

protocol DeviceScanner: DeviceScanning2 {
	associatedtype Device: DeviceIdentifiable
	var devices: [Device] { get }
}

extension DeviceScanner {
	func snapshotDevices() -> [any DeviceIdentifiable] {
		devices.map { $0 as any DeviceIdentifiable }
	}

	func startObservingDevices(onChange: @escaping () -> Void) {
		func track() {
			withObservationTracking(
				{ _ = devices },
				onChange: {
					onChange()
					track()
				}
			)
		}
		track()
	}
}
