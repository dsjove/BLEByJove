//
//  RFIDDetection.swift
//  Infrastructure
//
//  Created by David Giovannini on 1/12/26.
//

import Foundation

public struct RFIDDetection: Equatable, Hashable, BTSerializable {
	public let reader: UInt32
	public let timestampMS: UInt32
	public let id: CountedBytes

	public var packedSize: Int {
		reader.packedSize + timestampMS.packedSize + id.packedSize
	}
	
	public init() {
		self.reader = 0
		self.timestampMS = 0
		self.id = .init()
	}
	
	public init(unpack data: Data, _ cursor: inout Int) throws {
		self.reader = try .init(unpack: data, &cursor)
		self.timestampMS = try .init(unpack: data, &cursor)
		self.id = try .init(unpack: data, &cursor)
	}

	public func pack(btData data: inout Data) {
		reader.pack(btData: &data)
		timestampMS.pack(btData: &data)
		id.pack(btData: &data)
	}
}
