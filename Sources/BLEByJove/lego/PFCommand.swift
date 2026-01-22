import Foundation

public enum PFPort: UInt8, CaseIterable, Hashable, Equatable, Codable, BTSerializable, CustomStringConvertible {
	case A = 0
	case B = 1

	public init() {
		self = .A
	}

	public var description: String {
		switch self {
		case .A: return "A"
		case .B: return "B"
		}
	}
}

public enum PFMode: UInt8, CaseIterable, Hashable, Equatable, Codable, BTSerializable, CustomStringConvertible {
	case combo = 0
	case single = 1
	//TODO: lineOfSight (combo on repeat)

	public init() {
		self = .combo
	}

	public var description: String {
		switch self {
		case .combo: return "combo"
		case .single: return "single"
		}
	}
}

public struct PFCommand: Hashable, Equatable, Codable, BTSerializable, CustomStringConvertible {
	public let channel: UInt8 // 1..4
	public let port: PFPort
	public let power: Int8
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

	public var description: String {
		"PFCommand(channel: \(channel), port: \(port), power: \(power), mode: \(mode))"
	}

	public init(channel: UInt8 = 1, port: PFPort = .A, power: Int8 = 0, mode: PFMode = .combo) {
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

public protocol PFTransmitter {
	func transmit(cmd: PFCommand) -> Void
	var pfConnectionState: ConnectionState { get }
}

public protocol PFDeviceTransmitter {
	func transmit(port: PFPort, power: Int8) -> Void
	var pfConnectionState: ConnectionState { get }
}
