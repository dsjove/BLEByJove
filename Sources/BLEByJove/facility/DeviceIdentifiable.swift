//
//  DeviceIdentifiable 2.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation

public enum ConnectionState: String {
	case disconnected
	case connecting
	case connected
}

public protocol DeviceIdentifiable: Identifiable {
	var id: UUID { get }
	var name: String { get }
}
