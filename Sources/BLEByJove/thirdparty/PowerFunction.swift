//
//  PowerFunction.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/16/26.
//
import Foundation

public enum PFPort: UInt8, CaseIterable, Hashable, Equatable, BTSerializable {
	case A = 0
	case B = 1

	public init() {
		self = .A
	}
}

public enum PFMode: UInt8, CaseIterable, Hashable, Equatable, BTSerializable {
	case combo = 0
	case single = 1

	public init() {
		self = .combo
	}
}

public struct PFCommand: Hashable, Equatable, BTSerializable {
	public let channel: UInt8 // 1..4
	public let port: PFPort
	public let power: UInt8 // 0..15
	public let mode: PFMode

	public var packedSize: Int {
		4
	}

	public init() {
		self.channel = 1
		self.port = .A
		self.power = 0
		self.mode = .combo
	}

	public init(channel: UInt8 = 1, port: PFPort = .A, power: UInt8 = 0, mode: PFMode = .combo) {
		self.channel = channel
		self.port = port
		self.power = power
		self.mode = mode
	}

	public init(unpack data: Data, _ cursor: inout Int) throws {
		channel = try .init(unpack: data, &cursor)
		port = try .init(unpack: data, &cursor)
		power = try .init(unpack: data, &cursor)
		mode = try .init(unpack: data, &cursor)
	}

	public func pack(btData data: inout Data) {
		channel.pack(btData: &data)
		port.pack(btData: &data)
		power.pack(btData: &data)
		mode.pack(btData: &data)
	}
}

public final actor PowerFunction {
	private let device: BTDevice

	public var id: UUID {
		device.id
	}

	public init(device: BTDevice) {
		self.device = device
	}
}
