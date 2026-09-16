//
//  DeviceScanning.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation
import SBJFoundation

public enum ConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
}

public extension ConnectionState {
    var imageReference: ImageReference {
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

@MainActor
public protocol DeviceScanning: AnyObject {
    var scanning: Bool { get set }
}

@MainActor
public protocol DeviceScanner: DeviceScanning {
    associatedtype Device: DeviceIdentifiable
    var devices: [Device] { get }
}
