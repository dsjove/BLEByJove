//
//  ArduinoR4Matrix.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/23/25.
//

import Foundation
import Combine

public extension Array {
	//TODO: make more efficient
	mutating func shift(increment: Int = 1, fill: Element? = nil) {
		if increment > 0 {
			let r = (count-increment)..<count
			let v = fill.map{Array(repeating: $0, count: increment)} ?? Array(self[r])
			removeSubrange(r)
			insert(contentsOf: v, at: 0)
		}
		else {
			let r = 0..<abs(increment)
			let v = fill.map{ Array(repeating: $0, count: increment)} ?? Array(self[r])
			removeSubrange(r)
			append(contentsOf: v)
		}
	}
}

public struct ArduinoR4Matrix: Equatable, BTSerializable {
	public let columns = 12
	public let rows = 8
	private(set) var grid: [[Bool]]

	public init() {
		grid = Array(repeating: Array(repeating: false, count: columns), count: rows)
	}

	public subscript(r: Int, c: Int) -> Bool {
		get { grid[r][c] }
		set { grid[r][c] = newValue }
	}

	public enum FillStyle {
		case off
		case on
		case toggle
		case random
	}

	public mutating func fill(_ style: FillStyle = .off) {
		for r in 0..<grid.count {
			for c in 0..<grid[r].count {
				switch style {
				case .off:
					grid[r][c] = false
				case .on:
					grid[r][c] = true
				case .toggle:
					grid[r][c].toggle()
				case .random:
					grid[r][c] = Bool.random()
				}
			}
		}
	}

	public mutating func flip(_ columns: Bool = false, _ rows: Bool = false) {
		if columns {
			for r in 0..<grid.count {
				grid[r].reverse()
			}
		}
		if (rows) {
			grid.reverse()
		}
	}

	public mutating func scroll(_ columns: Bool = true, _ increment: Int = 1, _ fill: Bool? = nil) {
		if columns {
			for r in 0..<grid.count {
				grid[r].shift(increment: increment, fill: fill)
			}
		}
		else {
			grid.shift(increment: increment, fill: fill.flatMap{Array(repeating: $0, count: self.columns)})
		}
	}

	public let packedSize = 12

	public init(unpack data: Data, _ cursor: inout Int) throws {
		if data.count < packedSize {
			throw BTSerializeError.invalidDataLength
		}
		var result: [[Bool]] = Array(repeating: Array<Bool>(repeating: false, count: columns), count: rows)
		var r = 0
		var c = 0
		for _ in 0..<3 {
			let chunk = try UInt32(unpack: data, &cursor)
			for bitCounter in 0..<32 {
				let value = ((chunk >> (31 - bitCounter)) & 0x00000001) != 0
				result[r][c] = value
				c += 1
				if c == columns {
					c = 0
					r += 1
				}
			}
		}
		grid = result
	}

	public func pack(btData data: inout Data) {
		var bitCounter = 0
		var chunk: UInt32 = 0
		for row in grid {
			for value in row {
				chunk |= (value ? 1 : 0) << (31 - bitCounter)
				bitCounter += 1
				if (bitCounter == 32) {
					chunk.pack(btData: &data)
					bitCounter = 0
					chunk = 0
				}
			}
		}
	}

	public func export(name: String) -> String {
		let data = self.pack()
		var uint32Array = [UInt32]()
		data.withUnsafeBytes { rawBufferPointer in
			let bufferPointer = rawBufferPointer.bindMemory(to: UInt32.self)
			uint32Array = bufferPointer.map { $0 }
		}
		let elements = uint32Array.map { "0x" + String(format: "%08x", $0) }.joined(separator: ", ")
		let cArrayString = "const std::array<uint32_t, 3> \(name) = {\(elements)};\n"
		return cArrayString
	}
}
