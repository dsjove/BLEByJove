//
//  ScaledTransformerTests.swift
//  BLEByJoveTests
//
//  Created by David Giovannini on 3/25/25.
//

import XCTest
@testable import BLEByJove

extension Double {
	func isEquivelent(_ b: Double, tolerance: Double = 1e-10) -> Bool {
		return abs(self - b) <= tolerance
	}
}

final class ScaledTransformerTests: XCTestCase {
	func testSignedUpper() {
		let st = ScaledTransformer<Int8>(10)
		let p = st.transform(memento: 11)
		XCTAssertTrue(p?.isEquivelent(1.0) ?? false)
		let p2 = 1.01
		let m = st.transform(published: p2)
		XCTAssertEqual(m, 10)
	}

	func testSignedMid() {
		let st = ScaledTransformer<Int8>(10)
		let p = st.transform(memento: 0)
		XCTAssertTrue(p?.isEquivelent(0.0) ?? false)
		let p2 = p!
		let m = st.transform(published: p2)
		XCTAssertEqual(m, 0)
	}

	func testSignedLower() {
		let st = ScaledTransformer<Int8>(10)
		let p = st.transform(memento: -11)
		XCTAssertTrue(p?.isEquivelent(-1.0) ?? false)
		let p2 = -1.01
		let m = st.transform(published: p2)
		XCTAssertEqual(m, -10)
	}

	func testUnSignedUpper() {
		let st = ScaledTransformer<UInt8>(10)
		let p = st.transform(memento: 11)
		XCTAssertTrue(p?.isEquivelent(1.0) ?? false)
		let p2 = 1.01
		let m = st.transform(published: p2)
		XCTAssertEqual(m, 10)
	}

	func testUnSignedMid() {
		let st = ScaledTransformer<UInt8>(10)
		let p = st.transform(memento: 5)
		XCTAssertTrue(p?.isEquivelent(0.5) ?? false)
		let p2 = p!
		let m = st.transform(published: p2)
		XCTAssertEqual(m, 5)
	}

	func testUnSignedLower() {
		let st = ScaledTransformer<UInt8>(10)
		let p = st.transform(memento: 0)
		XCTAssertTrue(p?.isEquivelent(0.0) ?? false)
		let p2 = -0.01
		let m = st.transform(published: p2)
		XCTAssertEqual(m, 0)
	}
}

