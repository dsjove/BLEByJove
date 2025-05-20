//
//  BTControl.swift
//  BLEByJove
//
//  Created by David Giovannini on 5/20/25.
//

import Foundation
import Combine

public enum ConnectionState: String {
	case disconnected
	case connecting
	case connected
}

public protocol BTControl {
	var connectionState: ConnectionState { get }
	func connect()
	func disconnect()
}
