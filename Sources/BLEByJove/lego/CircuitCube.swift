//
//  CircuitCube.swift
//  BLEByJove
//
//  Created by David Giovannini on 12/11/22.
//

import Foundation
import SBJFoundation

@MainActor
public final class CircuitCube {
    private struct Component: BTComponent {
        let rawValue: UInt8 = 0x6e
    }

    private struct Category: BTCategory {
        let rawValue: UInt8 = 0x40
    }

    public static let Service = BTServiceIdentity(
        characteristic: BTCharacteristicIdentity(
            component: Component(),
            category: Category(),
            subCategory: EmptySubCategory(),
            channel: BTUARTChannel.duplex
        ),
        identifier: "b5a3f393e0a9e50e24dcca9e".sbjHexToData()!,
        name: "Circuit Cube"
    )

    private let device: BTDevice
    private let uart: BTUART

    public var id: UUID { device.id }

    public init(device: BTDevice) {
        self.device = device
        uart = BTUART(
            Self.Service.characteristic.apply(channel: BTUARTChannel.tx),
            Self.Service.characteristic.apply(channel: BTUARTChannel.rx),
            device
        )
    }

    public func connect() {
        device.connect()
        uart.connect()
    }

    public func disconnect() {
        uart.disconnect()
        device.disconnect()
    }

    public func battery() async -> Double? {
        let cmd = "b"
        return await uart.call(cmd.data(using: .ascii)) { data in
            guard let string = String(data: data, encoding: .ascii),
                  let value = Double(string) else { return nil }
            return value / 4.2
        }
    }

    // TODO: only works sometimes on the physical Circuit Cube; preserve command syntax while investigating.
    public func name() async -> String {
        let response = await uart.call("n?".data(using: .ascii)) { [weak self] data -> String? in
            guard let self else { return nil }
            let value = String(data: data, encoding: .ascii) ?? device.name
            device.name = value
            return value
        }
        if response == nil {
            print("Failed to get \(device.name) name")
        }
        return response ?? ""
    }

    // TODO: Does not work reliably on the physical Circuit Cube. Keep the existing documented wire form.
    public func name(set name: String = "") async -> Bool {
        let allowed = name.safeName()
        guard !allowed.isEmpty else { return false }

        device.name = allowed
        let cmd = "n=\(allowed)\r\n"
        let result = await uart.call(cmd.data(using: .ascii), timeout: 100) { $0 }
        let success = (result?.first ?? 1) == 0
        if !success {
            print("Failed to set \(device.name) name")
        }
        return success
    }

    public enum Port: String, Sendable {
        case a
        case b
        case c
    }

    public func power(set value: Int16, on port: Port, dropKey: String? = nil) async {
        await power(set: [port: value], dropKey: dropKey)
    }

    public func power(set value: Int16, on ports: [Port], dropKey: String? = nil) async {
        await power(
            set: ports.reduce(into: [:]) { $0[$1] = value },
            dropKey: dropKey
        )
    }

    public func power(set values: [Port: Int16], dropKey: String? = nil) async {
        let cmd = values.reduce("") {
            let node = String(format: "%+04d\($1.key.rawValue)", (-255...255).clamp($1.value))
            return $0 + node
        }
        uart.call(cmd.data(using: .ascii), dropKey: dropKey)
    }

    public func allOff() async -> Bool {
        await uart.call("0".data(using: .ascii)) { data in
            (data.first ?? 1) == 0
        } ?? false
    }
}

private extension String {
    func safeName() -> String {
        let allowed = CharacterSet(charactersIn: " _-0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        let filtered = trimmingCharacters(in: allowed.inverted)
        return String(filtered.prefix(20))
    }
}
