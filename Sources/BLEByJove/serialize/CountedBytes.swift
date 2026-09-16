//
//  CountedBytes.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/22/26.
//

import Foundation
import SBJFoundation

// TODO: use ULEB128_u64 for count if the wire protocol ever needs payloads > 255 bytes.
public struct CountedBytes: Equatable, Hashable, Codable, BTSerializable, CustomStringConvertible, Sendable {
    public var id: Data
    public var packedSize: Int { UInt8.packedSize + id.count }

    public init() {
        id = Data()
    }

    public init(_ data: Data) throws {
        guard data.count <= Int(UInt8.max) else {
            throw BTSerializeError.invalidDataLength
        }
        id = data
    }

    public init(unpack data: Data, _ cursor: inout Int) throws {
        let count = Int(try UInt8(unpack: data, &cursor))
        guard cursor >= 0, cursor <= data.count, count <= data.count - cursor else {
            throw BTSerializeError.invalidDataLength
        }
        id = Data(data[cursor..<(cursor + count)])
        cursor += count
    }

    public func pack(btData data: inout Data) {
        precondition(id.count <= Int(UInt8.max), "CountedBytes payload exceeds UInt8 wire length")
        UInt8(id.count).pack(btData: &data)
        data.append(id)
    }

    public var description: String {
        id.sbjHexFormat(bytesPerRow: 128)
    }
}
