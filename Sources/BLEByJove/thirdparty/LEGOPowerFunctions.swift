//
//  LEGOPowerFunctions.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/14/26.
//
import Foundation

public enum PFPort: UInt8, CaseIterable, Hashable, Equatable, BTSerializable {
	case A = 0
	case B = 1

	public init() {
		self = .A
	}
}

public struct PFCommand: Hashable, Equatable, BTSerializable {
	public let channel: UInt8 // 1..4
	public let port: PFPort
	public let power: UInt8 // 0..15

	public var packedSize: Int {
		3
	}

	public init() {
		self.channel = 1
		self.port = .A
		self.power = 0
	}

	public init(channel: UInt8 = 1, port: PFPort = .A, power: UInt8 = 0) {
		self.channel = channel
		self.port = port
		self.power = power
	}

	public init(unpack data: Data, _ cursor: inout Int) throws {
		channel = try .init(unpack: data, &cursor)
		port = try .init(unpack: data, &cursor)
		power = try .init(unpack: data, &cursor)
	}

	public func pack(btData data: inout Data) {
		channel.pack(btData: &data)
		port.pack(btData: &data)
		power.pack(btData: &data)
	}
}
