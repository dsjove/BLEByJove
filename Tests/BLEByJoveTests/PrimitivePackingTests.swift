//
//  PrimitivePackingTests.swift
//  BLEByJoveTests
//
//  Created by David Giovannini on 3/25/25.
//

import XCTest
@testable import BLEByJove

final class PrimitivePackingTests: XCTestCase {
	func testStackedIntegers() {
		var data = Data()
		Int32(0x12345678).pack(btData: &data)
		UInt16(0x8765).pack(btData: &data)
		Bool(false).pack(btData: &data)
		Bool(true).pack(btData: &data)
		Int64(0x1234567890abcdef).pack(btData: &data)
		XCTAssertEqual(16, data.count)
		XCTAssertEqual(data, Data([
			0x78, 0x56, 0x34, 0x12,
			0x65, 0x87,
			0x00,
			0x01,
			0xEF, 0xCD, 0xAB, 0x90, 0x78, 0x56, 0x34, 0x12,
		]))
		var cursor = 0
		XCTAssertEqual(0x12345678, try? Int32(unpack: data, &cursor))
		XCTAssertEqual(0x8765, try? UInt16(unpack: data, &cursor))
		XCTAssertEqual(false, try? Bool(unpack: data, &cursor))
		XCTAssertEqual(true, try? Bool(unpack: data, &cursor))
		XCTAssertEqual(0x1234567890abcdef, try? Int64(unpack: data, &cursor))
	}
}
