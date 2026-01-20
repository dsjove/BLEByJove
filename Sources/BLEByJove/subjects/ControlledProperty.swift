//
//  ControlledProperty.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25
//

import Foundation
import Observation
import Combine

public protocol ControlledProperty: Identifiable, AnyObject {
	associatedtype P
	
	var id: CombineIdentifier { get }
	
	var control: P { get set }
	var feedback: P { get }

	//TODO: implement
	//var canWrite: Bool { get }
	//var canRead: Bool { get }
	//var hasNotify: Bool { get }

	func reset()
}

@Observable
public class LocalControlledProperty<P: DefaultInitializable>: ControlledProperty {
	public let id: CombineIdentifier = .init()
	private let defaultValue: P

	init(defaultValue: P = .init()) {
		self.defaultValue = defaultValue
		self.control = defaultValue
		self.feedback = defaultValue
	}

	public var control: P {
		didSet {
			feedback = control
		}
	}

	public private(set) var feedback: P

	public func reset() {
		self.control = defaultValue
	}
}

@Observable
public class TransformedProperty<T: ValueTransforming>: ControlledProperty {
	public typealias P = T.P
	public typealias M = T.M

	public let id = CombineIdentifier()
	public let sendControl: ((M) -> M?)?
	public let transfomer: T
	public let defaultValue: P

	public private(set) var controlMomento: M?
	public private(set) var feedbackMomento: M?

	public init(
			sendControl: ((M) -> M?)?,
			transfomer: T,
			defaultValue: P = P()) {
		self.sendControl = sendControl
		self.transfomer = transfomer
		self.defaultValue = defaultValue
		self.control = defaultValue
		self.feedback = defaultValue
	}

	public var control: P {
		didSet {
			issueControl(oldValue)
		}
	}

	public private(set) var feedback: P

	public func reset() {
		control = defaultValue
		controlMomento = nil
		feedback = defaultValue
		feedbackMomento = nil
	}

	public func issueControl(_ oldValue: P) {
		if let sendControl, oldValue != control {
			let newControlMomento = transfomer.transform(published: control)
			if controlMomento != newControlMomento {
				controlMomento = newControlMomento
				let autoFeedback = sendControl(newControlMomento)
				if let autoFeedback {
					receiveFeedback(newFeedbackMomento: autoFeedback)
				}
			}
		}
	}

	public func receiveFeedback(newFeedbackMomento: M?) {
		if let newFeedbackMomento {
			if newFeedbackMomento != feedbackMomento {
				feedbackMomento = newFeedbackMomento
				let feedback = self.transfomer.transform(memento: newFeedbackMomento, old: self.control)
				if let feedback {
					self.feedback = feedback
					if self.controlMomento == nil {
						self.controlMomento = newFeedbackMomento
						self.control = feedback
					}
				}
			}
		}
	}
}
