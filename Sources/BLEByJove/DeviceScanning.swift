//
//  DeviceScanning.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation
import SBJKit

public enum ConnectionState: String {
	case disconnected
	case connecting
	case connected
}

extension ConnectionState {
	public var imageName: ImageName {
		switch self {
		case .disconnected:
			.system("cable.connector.slash")
		case .connecting:
			.system("arrow.triangle.2.circlepath")
		case .connected:
			.system("cable.connector")
		}
	}
}

public protocol DeviceIdentifiable: Identifiable {
	var id: UUID { get }
}

public protocol DeviceScanning: AnyObject {
	var scanning: Bool { get set }
}

public protocol DeviceScanner: DeviceScanning {
	associatedtype Device: DeviceIdentifiable
	var devices: [Device] { get }
}
