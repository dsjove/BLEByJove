//
//  BTServiceIdentity.swift
//  BLEByJove
//
//  Created by David Giovannini on 7/4/21.
//

import Foundation
import CoreBluetooth

public protocol BTComponent: CustomStringConvertible {
	var rawValue: UInt8 { get }
}

public extension BTComponent {
	var bitValue: UInt32 {
		UInt32(rawValue) << 24
	}
	
	var description: String {
		rawValue.description
	}
}

public struct EmptyComponent: BTComponent {
	public let rawValue: UInt8 = 0
	public init() {}
}

public protocol BTCategory: CustomStringConvertible {
	var rawValue: UInt8 { get }
}

public extension BTCategory {
	var bitValue: UInt32 {
		UInt32(rawValue) << 16
	}
	
	var description: String {
		rawValue.description
	}
}

public struct EmptyCategory: BTCategory {
	public let rawValue: UInt8 = 0x00
	public init() {}
}

public protocol BTSubCategory: CustomStringConvertible {
	var rawValue: UInt8 { get }
}

public extension BTSubCategory {
	var bitValue: UInt32 {
		UInt32(rawValue) << 8
	}
	
	var description: String {
		rawValue.description
	}
}

public struct EmptySubCategory: BTSubCategory {
	public let rawValue: UInt8 = 0x00
	public init() {}
}

public protocol BTChannel: CustomStringConvertible {
	var rawValue: UInt8 { get }
}

public extension BTChannel {
	var bitValue: UInt32 {
		UInt32(rawValue) << 0
	}

	var description: String {
		rawValue.description
	}
}

//TODO: Combine with BTUARTChannel
public enum BTPropChannel: UInt8, BTChannel {
	case property = 0
	case control = 1
	case feedback = 2
	
	public var description: String {
		switch self {
		case .property:
			return "P"
		case .control:
			return "C"
		case .feedback:
			return "F"
		}
	}
}

public enum BTUARTChannel: UInt8, BTChannel {
	case duplex = 1
	case tx = 2
	case rx = 3

	public var description: String {
		switch self {
		case .duplex:
			return "Duplex"
		case .tx:
			return "TX"
		case .rx:
			return "RX"
		}
	}
}

public struct BTCharacteristicIdentity: Hashable, CustomStringConvertible {
	public let component: BTComponent
	public let category: BTCategory
	public let subCategory: BTSubCategory
	public let channel: BTChannel
	public let bitValue: UInt32

	public init() {
		self.init(
			component: EmptyComponent(),
			category: EmptyCategory(),
			subCategory: EmptySubCategory(),
			channel: BTPropChannel.property)
	}

	public init(
			component: BTComponent = EmptyComponent(),
			category: BTCategory = EmptyCategory(),
			subCategory: BTSubCategory = EmptySubCategory(),
			channel: BTChannel = BTPropChannel.property) {
		self.component = component
		self.category = category
		self.subCategory = subCategory
		self.channel = channel
		self.bitValue = (component.bitValue | category.bitValue | subCategory.bitValue | channel.bitValue).bigEndian
	}
	
	public func apply(channel: BTChannel) -> BTCharacteristicIdentity {
		BTCharacteristicIdentity(
			component: component,
			category: category,
			subCategory: subCategory,
			channel: channel)
	}
	
	public static func == (lhs: BTCharacteristicIdentity, rhs: BTCharacteristicIdentity) -> Bool {
		rhs.bitValue == lhs.bitValue
	}
	
	public func hash(into hasher: inout Hasher) {
		bitValue.hash(into: &hasher)
	}
	
	public var description: String {
		"\(self.category).\(self.subCategory)[\(self.channel)]"
	}
}

public struct BTServiceIdentity: CustomStringConvertible, Hashable {
	public let characteristic: BTCharacteristicIdentity
	public let name: String
	public let identifer: CBUUID

	public init(name: String) {
		self.init(characteristic: BTCharacteristicIdentity(), identifier: name.data(using: .ascii)!, name: name)
	}

	public init(characteristic: BTCharacteristicIdentity, name: String) {
		self.init(characteristic: characteristic, identifier: name.data(using: .ascii)!, name: name)
	}

	public init(characteristic: BTCharacteristicIdentity, identifier: Data, name: String) {
		self.characteristic = characteristic
		self.name = name
		var data = Data(capacity: 16)
		var code = characteristic.bitValue.littleEndian
		let prefix = Data(bytes: &code, count: MemoryLayout<UInt32>.size)
		data.append(prefix)
		var normalized = identifier.prefix(12)
		if normalized.count < 12 {
			normalized.append(Data(repeating: 0x00, count: 12 - normalized.count))
		}
		data.append(contentsOf: normalized)
		self.identifer = CBUUID(data: data)
	}
	
	public var description: String {
		name
	}

	public func characteristic(characteristic: BTCharacteristicIdentity) -> CBUUID {
		var data = identifer.data
		var code = characteristic.bitValue.littleEndian
		let prefix = Data(bytes: &code, count: MemoryLayout<UInt32>.size)
		data.replaceSubrange(0..<4, with: prefix)
		return CBUUID(data: data)
	}
}
