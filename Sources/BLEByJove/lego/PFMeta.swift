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
}
