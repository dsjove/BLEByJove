//
//  BTSerializable.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25.
//

import Foundation
import Network

public protocol DefaultInitializable {
    init()
}

public enum BTSerializeError: Error, Equatable {
    case invalidDataLength
    case invalidRawValue
}

public protocol BTPackable {
    func pack(btData data: inout Data)
    var packedSize: Int { get }
}

public extension BTPackable {
    func pack() -> Data {
        var data = Data(capacity: packedSize)
        pack(btData: &data)
        return data
    }
}

public protocol BTUnpackable {
    init(unpack data: Data, _ cursor: inout Int) throws
}

public extension BTUnpackable {
    init(unpack data: Data) throws {
        var cursor = 0
        try self.init(unpack: data, &cursor)
    }
}

public typealias BTSerializable = BTPackable & BTUnpackable & DefaultInitializable

extension UInt8: BTSerializable {}
extension Int8: BTSerializable {}
extension UInt16: BTSerializable {}
extension Int16: BTSerializable {}
extension UInt32: BTSerializable {}
extension Int32: BTSerializable {}
extension UInt64: BTSerializable {}
extension Int64: BTSerializable {}

extension Double: DefaultInitializable {}

public extension FixedWidthInteger {
    var packedSize: Int { Self.packedSize }

    static var packedSize: Int { MemoryLayout<Self>.size }

    init(unpack data: Data, _ cursor: inout Int) throws {
        let size = Self.packedSize
        guard cursor >= 0, cursor <= data.count, size <= data.count - cursor else {
            throw BTSerializeError.invalidDataLength
        }

        // BLE payloads are byte streams; cursor offsets are not guaranteed to be naturally aligned.
        let encoded: Self = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: cursor, as: Self.self)
        }
        self = Self(littleEndian: encoded)
        cursor += size
    }

    func pack(btData data: inout Data) {
        var value = littleEndian
        withUnsafeBytes(of: &value) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}

extension Bool: BTSerializable {
    public var packedSize: Int { Self.packedSize }
    public static var packedSize: Int { UInt8.packedSize }

    public init(unpack data: Data, _ cursor: inout Int) throws {
        self = try UInt8(unpack: data, &cursor) != 0
    }

    public func pack(btData data: inout Data) {
        UInt8(self ? 1 : 0).pack(btData: &data)
    }
}

extension IPv4Address: BTSerializable {
    public init() {
        self.init("0.0.0.0")!
    }

    public var packedSize: Int { Self.packedSize }
    public static var packedSize: Int { 4 }

    public func pack(btData data: inout Data) {
        data.append(rawValue)
    }

    public init(unpack data: Data, _ cursor: inout Int) throws {
        let size = Self.packedSize
        guard cursor >= 0, cursor <= data.count, size <= data.count - cursor else {
            throw BTSerializeError.invalidDataLength
        }
        let bytes = Data(data[cursor..<(cursor + size)])
        guard let instance = IPv4Address(bytes) else {
            throw BTSerializeError.invalidDataLength
        }
        self = instance
        cursor += size
    }
}

public extension BTUnpackable where Self: RawRepresentable, Self.RawValue: BTUnpackable {
    init(unpack data: Data, _ cursor: inout Int) throws {
        let value = try Self.RawValue(unpack: data, &cursor)
        guard let found = Self(rawValue: value) else {
            throw BTSerializeError.invalidRawValue
        }
        self = found
    }
}

public extension BTPackable where Self: RawRepresentable, Self.RawValue: BTPackable {
    var packedSize: Int { rawValue.packedSize }

    func pack(btData data: inout Data) {
        rawValue.pack(btData: &data)
    }
}
