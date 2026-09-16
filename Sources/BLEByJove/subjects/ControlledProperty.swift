//
//  ControlledProperty.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25
//

import Foundation
import Observation

@MainActor
public protocol ControlledProperty: Identifiable, AnyObject {
    associatedtype P

    var id: UUID { get }
    var control: P { get set }
    var feedback: P { get }
    func reset()
}

@MainActor
@Observable
public final class LocalControlledProperty<P: DefaultInitializable>: ControlledProperty {
    public nonisolated let id = UUID()
    private let defaultValue: P

    public init(defaultValue: P = .init()) {
        self.defaultValue = defaultValue
        control = defaultValue
        feedback = defaultValue
    }

    public var control: P {
        didSet { feedback = control }
    }

    public private(set) var feedback: P

    public func reset() {
        control = defaultValue
    }
}

@MainActor
@Observable
public class TransformedProperty<T: ValueTransforming>: ControlledProperty {
    public typealias P = T.P
    public typealias M = T.M

    public nonisolated let id = UUID()
    public let sendControl: ((M) -> M?)?
    public let transfomer: T
    public let defaultValue: P

    public private(set) var controlMomento: M?
    public private(set) var feedbackMomento: M?

    public init(
        sendControl: ((M) -> M?)?,
        transfomer: T,
        defaultValue: P = P()
    ) {
        self.sendControl = sendControl
        self.transfomer = transfomer
        self.defaultValue = defaultValue
        control = defaultValue
        feedback = defaultValue
    }

    public var control: P {
        didSet { issueControl(oldValue) }
    }

    public private(set) var feedback: P

    public func reset() {
        control = defaultValue
        controlMomento = nil
        feedback = defaultValue
        feedbackMomento = nil
    }

    public func issueControl(_ oldValue: P) {
        guard let sendControl, oldValue != control else { return }
        let newControlMomento = transfomer.transform(published: control)
        guard controlMomento != newControlMomento else { return }

        controlMomento = newControlMomento
        if let autoFeedback = sendControl(newControlMomento) {
            receiveFeedback(newFeedbackMomento: autoFeedback)
        }
    }

    public func receiveFeedback(newFeedbackMomento: M?) {
        guard let newFeedbackMomento, newFeedbackMomento != feedbackMomento else { return }
        feedbackMomento = newFeedbackMomento

        guard let transformedFeedback = transfomer.transform(memento: newFeedbackMomento, old: control) else { return }
        feedback = transformedFeedback

        if controlMomento == nil {
            controlMomento = newFeedbackMomento
            control = transformedFeedback
        }
    }
}
