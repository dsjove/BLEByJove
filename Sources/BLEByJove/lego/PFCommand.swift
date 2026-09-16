import Foundation

public enum PFPort: UInt8, CaseIterable, Hashable, Equatable, Codable, BTSerializable, CustomStringConvertible, Sendable {
    case A = 0
    case B = 1

    public init() { self = .A }

    public var description: String {
        switch self {
        case .A: "A"
        case .B: "B"
        }
    }
}

public enum PFMode: UInt8, CaseIterable, Hashable, Equatable, Codable, BTSerializable, CustomStringConvertible, Sendable {
    case combo = 0
    case single = 1
    // TODO: lineOfSight (combo on repeat)

    public init() { self = .combo }

    public var description: String {
        switch self {
        case .combo: "combo"
        case .single: "single"
        }
    }
}

public struct PFCommand: Hashable, Equatable, Codable, BTSerializable, CustomStringConvertible, Sendable {
    public let channel: UInt8 // 1...4
    public let port: PFPort
    public let power: Int8
    public let mode: PFMode

    public var packedSize: Int { 4 }

    public init() {
        channel = 1
        port = .A
        power = 0
        mode = .combo
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

@MainActor
public protocol PFTransmitter {
    func transmit(cmd: PFCommand)
    var pfConnectionState: ConnectionState { get }
}

@MainActor
public protocol PFDeviceTransmitter {
    func transmit(port: PFPort, power: Int8)
    var pfConnectionState: ConnectionState { get }
}
