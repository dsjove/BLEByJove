import Foundation
import SBJFoundation

public extension UUID {
    init(dataBytes: Data) {
        var bytes = Data()
        bytes.reserveCapacity(16)
        bytes.append(dataBytes.prefix(16))
        if bytes.count < 16 {
            bytes.append(Data(repeating: 0, count: 16 - bytes.count))
        }
        let b = Array(bytes.prefix(16))
        self = .init(uuid: (
            b[0], b[1], b[2], b[3],
            b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11],
            b[12], b[13], b[14], b[15]
        ))
    }
}

/// One detection emitted by the physical RFID reader.
///
/// The RFID reader and this wire format are in active, known-working hardware use. Preserve
/// byte-level compatibility when changing serialization or surrounding infrastructure.
public struct RFIDDetection: Equatable, Hashable, Codable, BTSerializable, CustomStringConvertible, Sendable {
    public let reader: UInt32
    public let timestampMS: UInt32
    public let id: Data

    public var packedSize: Int {
        reader.packedSize + timestampMS.packedSize + UInt8.packedSize + id.count
    }

    public var description: String {
        "\(reader)-\(timestampMS)-\(id.sbjHexFormat())"
    }

    public init() {
        reader = 0
        timestampMS = 0
        id = .init()
    }

    public init(reader: UInt32, timeStampMS: UInt32 = 0, id: Data) {
        self.reader = reader
        timestampMS = timeStampMS
        self.id = id
    }

    public init(unpack data: Data, _ cursor: inout Int) throws {
        reader = try .init(unpack: data, &cursor)
        timestampMS = try .init(unpack: data, &cursor)
        id = try CountedBytes(unpack: data, &cursor).id
    }

    public func pack(btData data: inout Data) {
        reader.pack(btData: &data)
        timestampMS.pack(btData: &data)
        guard let countedBytes = try? CountedBytes(id) else {
            preconditionFailure("RFID id exceeds CountedBytes wire limit")
        }
        countedBytes.pack(btData: &data)
    }
}
