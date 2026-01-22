//
//  BTSerializable.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25.
//

import Foundation
import Network
import SBJKit

public protocol DefaultInitializable {
	init()
}

public enum BTSerializeError: Error {
	case invalidDataLength
	case invalidRawValue
}

public protocol BTPackable {
	func pack(btData data: inout Data)
	var packedSize: Int { get }
}

public extension BTPackable {
	func pack() -> Data {
		var data = Data(capacity: self.packedSize)
		self.pack(btData: &data)
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
	var packedSize: Int {
		Self.packedSize
	}
	
	static var packedSize: Int {
		MemoryLayout<Self>.size
	}

	//suffix of suffix does not work!, introduce cursor
	init(unpack data: Data, _ cursor: inout Int) throws {
		if data.count < MemoryLayout<Self>.size {
			throw BTSerializeError.invalidDataLength
		}
		//TODO: handle misaligned memory
		var value: Self
		value = data.withUnsafeBytes { pointer in
			pointer.load(fromByteOffset: cursor, as: Self.self)
		}
		self = Self(littleEndian: value)
		cursor += Self.packedSize
	}
	
	func pack(btData data: inout Data) {
		let value = self.littleEndian
		withUnsafePointer(to: value) { (ptr: UnsafePointer<Self>) in
			data.append(UnsafeBufferPointer(start: ptr, count: 1))
		}
	}
}

extension Bool: BTSerializable {
	public var packedSize: Int {
		Self.packedSize
	}
	
	public static var packedSize: Int {
		UInt8.packedSize
	}
	
	public init(unpack data: Data, _ cursor: inout Int) throws {
		self = try UInt8(unpack: data, &cursor) == 0 ? false : true
	}
	
	public func pack(btData data: inout Data) {
		UInt8(self ? 1 : 0).pack(btData: &data)
	}
}

extension IPv4Address : BTSerializable {
	public init() {
		self.init("0.0.0.0")!
	}
	
	public var packedSize: Int {
		IPv4Address.packedSize
	}
	
	public static var packedSize: Int {
		4
	}

	public func pack(btData data: inout Data) {
		data.append(rawValue);
	}
	
	public init(unpack data: Data, _ cursor: inout Int) throws {
		guard let instance = IPv4Address(data) else {
			throw BTSerializeError.invalidDataLength
		}
		self = instance
		cursor += packedSize;
	}
}

public extension BTUnpackable where Self: RawRepresentable, Self.RawValue: BTUnpackable {
	init(unpack data: Data, _ cursor: inout Int) throws {
		let value = try Self.RawValue(unpack: data, &cursor)
		if let found = Self(rawValue: value) {
			self = found
			return
		}
		throw BTSerializeError.invalidRawValue
	}
}

public extension BTPackable where Self: RawRepresentable, Self.RawValue: BTPackable {
	var packedSize: Int {
		rawValue.packedSize
	}
	
	func pack(btData data: inout Data) {
		rawValue.pack(btData: &data)
	}
}
