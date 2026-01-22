import Foundation
import Combine
import SBJKit

public struct PFMeta: CustomStringConvertible {
	public let id: Data // <= 16 size
	public let name: String
	public var image: ImageName
	public let channel: UInt8 // 1..4
	public let mode: PFMode
	public let timeout: TimeInterval
	public let uuid: UUID

	public init(id: Data, channel: UInt8, name: String, image: ImageName, mode: PFMode, timeout: TimeInterval = 0) {
		self.id = id
		self.channel = channel
		self.name = name
		self.image = image
		self.mode = mode
		self.timeout = timeout
		var bytes = Data();
		bytes.reserveCapacity(16)
		bytes.append(id.prefix(16))
		if bytes.count < 16 {
			bytes.append(Data(repeating: 0, count: 16 - bytes.count))
		}
		let b = Array(bytes.prefix(16))
		self.uuid = UUID(uuid: (
			b[0], b[1], b[2], b[3],
			b[4], b[5], b[6], b[7],
			b[8], b[9], b[10], b[11],
			b[12], b[13], b[14], b[15]
		))
	}

	public var description: String { name }
}
