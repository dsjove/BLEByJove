import Foundation
import Combine
import SBJKit

public protocol PFMeta {
	var id: Data { get } // <= 16 size
	var channel: UInt8 { get } // 1..4
	var mode: PFMode { get }
	var timeout: TimeInterval { get } 
}

extension PFMeta {
	var timeInterval: TimeInterval { 0 }
	var uuid: UUID {
		var bytes = Data();
		bytes.reserveCapacity(16)
		bytes.append(id.prefix(16))
		if bytes.count < 16 {
			bytes.append(Data(repeating: 0, count: 16 - bytes.count))
		}
		let b = Array(bytes.prefix(16))
		return UUID(uuid: (
			b[0], b[1], b[2], b[3],
			b[4], b[5], b[6], b[7],
			b[8], b[9], b[10], b[11],
			b[12], b[13], b[14], b[15]
		))
	}
}
