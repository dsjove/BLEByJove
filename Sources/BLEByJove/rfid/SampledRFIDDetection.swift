//
//  SampledRFIDDetection.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/22/26.
//

import Foundation

public struct SampledRFIDDetection: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    public let date: Date
    public let count: Int
    public let anotherRound: Bool
    public let rfid: RFIDDetection

    public init(
        date: Date = Date(),
        count: Int = 1,
        anotherRound: Bool = true,
        rfid: RFIDDetection
    ) {
        self.date = date
        self.count = count
        self.anotherRound = anotherRound
        self.rfid = rfid
    }

    public var description: String {
        "\(date): \(count)\(anotherRound ? "*" : "") - \(rfid)"
    }
}

@MainActor
public protocol RFIDProducing: AnyObject {
    var currentRFID: SampledRFIDDetection? { get }
    func resetRFID()
}

@MainActor
public protocol RFIDConsumer: AnyObject {
    func consumeRFID(_ detection: SampledRFIDDetection)
}
