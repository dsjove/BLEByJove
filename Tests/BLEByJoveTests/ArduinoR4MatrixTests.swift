//
//  ArduinoR4MatrixTests.swift
//  BLEByJoveTests
//
//  Created by David Giovannini on 3/25/25.
//

import XCTest
@testable import BLEByJove

final class ArduinoR4MatrixTests: XCTestCase {
	func testPacking() {
		var display = ArduinoR4Matrix()
		display.fill(.random)
		let packed = display.pack()
		XCTAssertEqual(packed.count, display.packedSize)

		let display2 = try? ArduinoR4Matrix(unpack: packed)
		XCTAssertEqual(display, display2)
	}
}
