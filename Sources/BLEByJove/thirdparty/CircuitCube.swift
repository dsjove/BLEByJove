//
//  CircuitCube.swift
//  BLEByJove
//
//  Created by David Giovannini on 12/11/22.
//

import Foundation
import Combine

public final actor CircuitCube {
	private struct Component: BTComponent {
		public let rawValue: UInt8 = 0x6e
		public init() {}
	}

	private struct Category: BTCategory {
		public let rawValue: UInt8 = 0x40
		public init() {}
	}

	public static let Service = BTServiceIdentity(
		characteristic: BTCharacteristicIdentity(
			component: Component(),
			category: Category(),
			subCategory: EmptySubCategory(),
			channel: BTUARTChannel.duplex),
		identifier: "b5a3f393e0a9e50e24dcca9e".sbjHexToData()!,
		name: "Circuit Cube")

	private let device: BTDevice
	private let uart: BTUART

	public var id: UUID {
		device.id
	}

	public init(device: BTDevice) {
		self.device = device
		self.uart = BTUART(
			CircuitCube.Service.characteristic.apply(channel: BTUARTChannel.tx),
			CircuitCube.Service.characteristic.apply(channel: BTUARTChannel.rx),
			device)
	}

	public func connect() {
		DispatchQueue.main.sync {
			device.connect()
		}
		Task {
			await self.uart.connect()
		}
	}

	public func disconnect() {
		DispatchQueue.main.sync {
			device.connect()
		}
		Task {
			await self.uart.disconnect()
		}
		device.disconnect()
	}

	public func battery() async -> Double? {
		let cmd = "b"
		return await uart.call(cmd.data(using: String.Encoding.ascii)) { data in
			if let str = String(data: data, encoding: String.Encoding.ascii) {
				if let value = Double(str) {
					return value / 4.2
				}
			}
			return nil
		}
	}

	//TODO: only works sometimes
	public func name() async -> String {
		let cmd = "n?"
		let name = await uart.call(cmd.data(using: String.Encoding.ascii)) { data in
			DispatchQueue.main.sync {
				let name: String = String(data: data, encoding: String.Encoding.ascii) ?? self.device.name
				self.device.name = name
				return name
			}
		}
		if (name == nil) {
			print("Failed to get \(self.device.name) name")
		}
		return name ?? "" //self.device.name
	}

	//TODO: Does not work
	public func name(set name: String = "") async -> Bool {
		let allowed = name.safeName()
		if allowed.isEmpty {
			return false
		}
		DispatchQueue.main.async {
			self.device.name = allowed
		}
		//Conflicting docs with the '='
		let cmd = "n=\(allowed)\r\n"
		let result = await uart.call(cmd.data(using: String.Encoding.ascii), timeout: 100) { $0 }
		let success = (result?.first ?? 1) == 0
		if !success {
			print("Failed to set \(self.device.name) name")
		}
		return success
	}

	public enum Port: String {
		case a
		case b
		case c
	}

	public func power(set value: Int16, on port: Port, dropKey: String? = nil) async {
		await power(set: [port : value], dropKey: dropKey)
	}

	public func power(set value: Int16, on ports: [Port], dropKey: String? = nil) async {
		await power(set: ports.reduce([:]) {
			var a = $0
			a[$1] = value
			return a
		}, dropKey: dropKey)
	}

	public func power(set values: [Port: Int16], dropKey: String? = nil) async {
		let cmd = values.reduce("") {
			let node = String(format: "%+04d\($1.key.rawValue)", (-255...255).clamp($1.value))
			return $0 + node
		}
		await uart.call(cmd.data(using: String.Encoding.ascii), dropKey: dropKey)
	}

	public func allOff() async -> Bool {
		let cmd = "0"
		return await uart.call(cmd.data(using: String.Encoding.ascii)) { data in
			return (data.first ?? 1) == 0
		} ?? false
	}
}

private extension String {
	func safeName() -> String {
		let allowed = CharacterSet(charactersIn: " _-0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
		let filtered = self.trimmingCharacters(in: allowed.inverted)
		let trimmed = String(filtered.prefix(20))
		return trimmed
	}
}
