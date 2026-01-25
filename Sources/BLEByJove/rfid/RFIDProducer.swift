//
//  RFIDProducer.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/9/26.
//

import Foundation
import BLEByJove
import SBJKit
import Observation

@Observable
public class RFIDProducer: RFIDProducing {
	private typealias Value = BTProperty<BTValueTransformer<RFIDDetection>>
	private let noiseThresholdMS: Int
	private let silenceThresholdSecs: TimeInterval
	private var received: Value
	private var staleTimer: Timer?

	public private(set) var currentRFID: SampledRFIDDetection?

	public init(
			device: any BTBroadcaster,
			component: BTComponent = EmptyComponent(),
			category: BTCategory = EmptyCategory(),
			subCategory: BTSubCategory = EmptySubCategory(),
			noiseThresholdMS: Int = 3000,
			silenceThresholdSecs: TimeInterval = 180.0) {
		self.noiseThresholdMS = noiseThresholdMS
		self.silenceThresholdSecs = silenceThresholdSecs

		self.received = .init(
			broadcaster: device,
			characteristic: BTCharacteristicIdentity(
				component: component,
				category: category,
				subCategory: subCategory,
				channel: BTPropChannel.feedback))

		observeValue(of: received, \.feedback, with: self) { _, value, this in
			print(value)
			this?.updateCurrent(for: value)
		}
	}

	deinit {
		staleTimer?.invalidate()
	}

	public func receive(_ detection: RFIDDetection) {
		received.receiveFeedback(newFeedbackMomento: detection)
	}

	private func updateCurrent(for detection: RFIDDetection) {
		if detection.id.isZero {
			self.currentRFID = nil
		}
		else if let current = currentRFID, current.rfid.id == detection.id {
			let timeDiffMS = detection.timestampMS - current.rfid.timestampMS
			let anotherRound = timeDiffMS > noiseThresholdMS
			self.currentRFID = .init(
				count: current.count + (anotherRound ? 1 : 0),
				anotherRound: anotherRound,
				rfid: detection)
		}
		else {
			self.currentRFID = .init(
				count: 1,
				anotherRound: true,
				rfid: detection)
		}
		if silenceThresholdSecs > 0 {
			let detected = self.currentRFID
			DispatchQueue.main.async { [weak self] in
				self?.startStaleCheck(detected)
			}
		}
	}

	private func startStaleCheck(_ detected: SampledRFIDDetection?) {
		staleTimer?.invalidate()
		guard let detected else {
			staleTimer = nil
			return
		}
		staleTimer = Timer.scheduledTimer(withTimeInterval: silenceThresholdSecs, repeats: false) { [weak self] _ in
			guard let self = self else { return }
			if let current = self.currentRFID {
				if current.rfid == detected.rfid {
					self.currentRFID = nil
				}
			}
		}
	}

	public func resetRFID() {
		self.currentRFID = nil
		staleTimer?.invalidate()
		staleTimer = nil
		self.received.reset()
	}
}
