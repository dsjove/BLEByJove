//
//  DeviceIdentifiable.swift
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
			.system("progress.indicator")
		case .connected:
			.system("cable.connector")
		}
	}
}

public protocol DeviceIdentifiable: Identifiable {
	var id: UUID { get }
	var name: String { get }
}
