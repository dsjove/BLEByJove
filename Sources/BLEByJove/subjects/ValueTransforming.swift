//
//  ValueTransforming.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/25/25.
//

import Foundation

public protocol ValueTransforming {
	associatedtype P: DefaultInitializable & Equatable
	associatedtype M: Equatable

	func transform(published: P) -> M
	func transform(memento: M, old: P?) -> P?
}

public extension ValueTransforming {
	func transform(memento: M) -> P? {
		transform(memento: memento, old: nil)
	}
}

public extension ValueTransforming where P == M {
	func transform(published: P) -> M {
		return published
	}

	func transform(memento: M, old: P?) -> P? {
		return memento
	}
}

public struct BTValueTransformer<T: BTSerializable & Equatable & DefaultInitializable>: ValueTransforming {
	public typealias P = T
	public typealias M = T

	public init() {
	}

	public func transform(published: P) -> M {
		return published
	}
	
	public func transform(memento: M?, old: P?) -> P? {
		return memento
	}
}
