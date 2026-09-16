import Foundation

public protocol PFMeta {
    var id: Data { get } // <= 16 bytes
    var channel: UInt8 { get } // 1...4
    var mode: PFMode { get }
    var timeout: TimeInterval { get }
}
