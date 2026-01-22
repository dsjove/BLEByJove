//
//  CountedBytes.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/22/26.
//

import Foundation
import Network
import SBJKit

//TODO: use ULEB128_u64 for count
public struct CountedBytes: Equatable, Hashable, Codable, BTSerializable, CustomStringConvertible {
	public var id: Data
	public var packedSize: Int { id.count + 1 }

	public init() {
		self.id = Data()
	}

	public init(_ data: Data) throws {
		guard data.count <= UInt8.max else {
			throw BTSerializeError.invalidDataLength
		}
		var tmp = Data()
		tmp.reserveCapacity(1 + data.count)
		tmp.append(UInt8(data.count))
		tmp.append(contentsOf: data)
		self.id = tmp
	}

	public init(unpack data: Data, _ cursor: inout Int) throws {
		let count = Int(try UInt8(unpack: data, &cursor))
		guard data.count >= cursor + count else {
			throw BTSerializeError.invalidDataLength
		}
		id = data.subdata(in: cursor..<(cursor + count))
		cursor += count
	}

	public func pack(btData data: inout Data) {
		UInt8(packedSize).pack(btData: &data)
		data.append(contentsOf: id)
	}

	public var description: String {
		id.sbjHexFormat(bytesPerRow: 128)
	}
}
