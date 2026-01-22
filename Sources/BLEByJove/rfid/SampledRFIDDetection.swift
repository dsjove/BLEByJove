//
//  SampledRFIDDetection.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/22/26.
//


import Foundation
import BLEByJove
import SBJKit
import Observation

public struct SampledRFIDDetection: Equatable, Hashable, Codable, CustomStringConvertible  {
	public let date = Date()
	public let count: Int
	public let anotherRound: Bool
	public let rfid: RFIDDetection

	public init(count: Int = 1, anotherRound: Bool = true, rfid: RFIDDetection) {
		self.count = count
		self.anotherRound = anotherRound
		self.rfid = rfid
	}

	public var description: String {
		"\(date): \(count)\(anotherRound ? "*" : "") - \(rfid)"
	}
}

public protocol RFIDProducing {
	var currentRFID: SampledRFIDDetection? { get }
}

public protocol RFIDConsumer {
	func consumeRFID(_ detection: SampledRFIDDetection)
}
