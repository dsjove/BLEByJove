//
//  Data+Hex.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25.
//

import Foundation

public extension Data {
	var sbjHexDescription: String {
		"\n\(sbjHexFormat(bytesPerRow: 16, indent: "\t"))"
	}
	
	func sbjHexFormat(bytesPerRow: Int = Int.max, indent: String = "") -> String {
		if self.isEmpty {
			return "\(indent)-\n)"
		}
		var desc = reduce(("", 1)) { a, e in
			var iter = a
			let i = (iter.1-1) % bytesPerRow == 0 ? indent : ""
			let val = String(format: "%02x", e)
			let term = iter.1 % bytesPerRow == 0 ? "\n" : iter.1 % 2  == 0 ? " " :  "."
			iter.0 = iter.0 + "\(i)\(val)\(term)"
			iter.1 += 1
			return iter
		}
		desc.0.removeLast()
		return desc.0
	}

	func sbjUnpackVariableSizedInteger(from data: Data) -> UInt64? {
		var value: UInt64 = 0
		var shift: UInt64 = 0

		for byte in data {
			let maskedByte = UInt64(byte & 0x7F) // Extract the last 7 bits
			value |= maskedByte << shift
			shift += 7
			if (byte & 0x80) == 0 { // Check continuation bit
				return value
			}
		}
		return nil // Return nil if data is incomplete
	}

	func sbjPackVariableSizedInteger(_ value: UInt64) -> Data {
		var encodedData = Data()
		var tempValue = value

		// Encode using VLQ (Variable-length Quantity)
		repeat {
			var byte = UInt8(tempValue & 0x7F) // Take the last 7 bits
			tempValue >>= 7 // Shift right by 7 bits
			if tempValue != 0 {
				byte |= 0x80 // Set the continuation bit
			}
			encodedData.append(byte)
		} while tempValue != 0

		return encodedData
	}
}

public extension String {
	func sbjHexToData() -> Data? {
		var data = Data()
		var tempHex = self
		
		// Ensure even-length string
		if tempHex.count % 2 != 0 {
			tempHex = "0" + tempHex
		}
		
		for i in stride(from: 0, to: tempHex.count, by: 2) {
			let start = tempHex.index(tempHex.startIndex, offsetBy: i)
			let end = tempHex.index(start, offsetBy: 2)
			let byteString = String(tempHex[start..<end])
			
			if let byte = UInt8(byteString, radix: 16) {
				data.append(byte)
			} else {
				return nil // Invalid hex string
			}
		}
		return data
	}
}
