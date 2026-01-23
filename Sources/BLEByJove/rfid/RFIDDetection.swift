import Foundation
import SBJKit

public extension UUID {
	init(dataBytes: Data) {
		var bytes = Data();
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

public struct RFIDDetection: Equatable, Hashable, Codable, BTSerializable, CustomStringConvertible {
	public let reader: UInt32
	public let timestampMS: UInt32
	public let id: Data

	public var packedSize: Int {
		reader.packedSize + timestampMS.packedSize + id.count
	}

	public var description: String {
		"\(reader)-\(timestampMS)-\(id.sbjHexFormat())"
	}

	public init() {
		self.reader = 0
		self.timestampMS = 0
		self.id = .init()
	}

	public init(reader: UInt32, timeStampMS: UInt32 = 0, id: Data) {
		self.reader = reader
		self.timestampMS = timeStampMS
		self.id = id
	}

	public init(unpack data: Data, _ cursor: inout Int) throws {
		self.reader = try .init(unpack: data, &cursor)
		self.timestampMS = try .init(unpack: data, &cursor)
		let countedBytes = try CountedBytes(unpack: data, &cursor)
		self.id = countedBytes.id
	}

	public func pack(btData data: inout Data) {
		reader.pack(btData: &data)
		timestampMS.pack(btData: &data)
		let countedBytes = (try? CountedBytes(id)) ?? .init()
		countedBytes.pack(btData: &data)
	}
}
