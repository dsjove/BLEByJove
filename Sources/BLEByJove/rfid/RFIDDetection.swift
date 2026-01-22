import Foundation

public struct RFIDDetection: Equatable, Hashable, Codable, BTSerializable, CustomStringConvertible {
	public let reader: UInt32
	public let timestampMS: UInt32
	public let id: Data

	public var packedSize: Int {
		reader.packedSize + timestampMS.packedSize + id.count
	}

	public var description: String {
		"\(reader)-\(timestampMS)-\(id)"
	}

	public init() {
		self.reader = 0
		self.timestampMS = 0
		self.id = .init()
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
