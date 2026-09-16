//
//  RFIDProducer.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/9/26.
//

import Foundation
import Observation
import SBJFoundation

/// Converts the known-working RFID reader's raw detections into sampled/current RFID state.
/// Preserve the existing reader timing semantics unless a hardware-backed change is intentional.
@MainActor
@Observable
public final class RFIDProducer: RFIDProducing {
    private typealias Value = BTProperty<BTValueTransformer<RFIDDetection>>

    private let noiseThresholdMS: Int
    private let silenceThresholdSecs: TimeInterval
    private var received: Value
    private var staleTimer: Timer?
    private var observation: ObserveToken?

    public private(set) var currentRFID: SampledRFIDDetection?

    public init(
        device: any BTBroadcaster,
        component: BTComponent = EmptyComponent(),
        category: BTCategory = EmptyCategory(),
        subCategory: BTSubCategory = EmptySubCategory(),
        noiseThresholdMS: Int = 3000,
        silenceThresholdSecs: TimeInterval = 180.0
    ) {
        self.noiseThresholdMS = noiseThresholdMS
        self.silenceThresholdSecs = silenceThresholdSecs

        received = .init(
            broadcaster: device,
            characteristic: BTCharacteristicIdentity(
                component: component,
                category: category,
                subCategory: subCategory,
                channel: BTPropChannel.feedback
            )
        )

        observation = observeValue(of: received, \.feedback, with: self) { _, value, producer in
            producer?.updateCurrent(for: value)
        }
    }

    isolated deinit {
        staleTimer?.invalidate()
        observation?.cancel()
    }

    public func receive(_ detection: RFIDDetection) {
        received.receiveFeedback(newFeedbackMomento: detection)
    }

    private func updateCurrent(for detection: RFIDDetection) {
        if detection.id.isZero {
            currentRFID = nil
        } else if let current = currentRFID, current.rfid.id == detection.id {
            // Reader timestamps are UInt32 milliseconds. Wrapping subtraction preserves elapsed
            // behavior if the embedded counter rolls over.
            let timeDiffMS = detection.timestampMS &- current.rfid.timestampMS
            let anotherRound = timeDiffMS > UInt32(clamping: noiseThresholdMS)
            currentRFID = .init(
                count: current.count + (anotherRound ? 1 : 0),
                anotherRound: anotherRound,
                rfid: detection
            )
        } else {
            currentRFID = .init(count: 1, anotherRound: true, rfid: detection)
        }

        startStaleCheck(currentRFID)
    }

    private func startStaleCheck(_ detected: SampledRFIDDetection?) {
        staleTimer?.invalidate()
        guard silenceThresholdSecs > 0, let detected else {
            staleTimer = nil
            return
        }

        staleTimer = Timer.scheduledTimer(withTimeInterval: silenceThresholdSecs, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.currentRFID?.rfid == detected.rfid else { return }
                self.currentRFID = nil
            }
        }
    }

    public func resetRFID() {
        currentRFID = nil
        staleTimer?.invalidate()
        staleTimer = nil
        received.reset()
    }
}
