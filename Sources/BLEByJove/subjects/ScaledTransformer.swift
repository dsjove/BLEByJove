//
//  ScaledTransformer.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25.
//

public extension ClosedRange {
	func clamp(_ value : Bound) -> Bound {
		self.lowerBound > value ? self.lowerBound :
		self.upperBound < value ? self.upperBound :
		value
	}
}

public extension Double {
	func isEquivelent(_ b: Double, epsilon: Double = 1e-10) -> Bool {
		abs(self - b) < epsilon
	}
}

public struct ScaledTransformer<T: FixedWidthInteger & BTSerializable & Equatable>: ValueTransforming {
	public typealias P = Double
	public typealias M = T
	public let magnitude: M

	public init(_ magnitude: M) {
		self.magnitude = magnitude
	}

	public func transform(published: P) -> M {
		let length = Double(magnitude)
		if T.isSigned {
			let normalized = (-1.0...1.0).clamp(published)
			let scaled = M(normalized * length)
			let clamped = ((-1 * magnitude)...magnitude).clamp(scaled)
			return clamped
		}
		let normalized = (0.0...1.0).clamp(published)
		let scaled = M(normalized * length)
		let clamped = (0...magnitude).clamp(scaled)
		return clamped
	}

	public func transform(memento: M, old: P?) -> P? {
		let length = Double(magnitude)
		if T.isSigned {
			let clamped = Double(((-1 * magnitude)...magnitude).clamp(memento))
			let scaled = clamped / length
			let normalized = (-1.0...1.0).clamp(scaled)
			return normalized
		}
		let clamped = Double((0...magnitude).clamp(memento))
		let scaled = clamped / length
		let normalized = (0.0...1.0).clamp(scaled)
		return normalized
	}
}
