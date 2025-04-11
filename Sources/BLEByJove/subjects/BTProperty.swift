//
//  BTProperty.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25
//

import Foundation
import Combine

public class BTProperty<T: ValueTransforming>: TransformedProperty<T>
		where T.P: Equatable, T.M: Equatable, T.M: BTSerializable {
	private var sink: AnyCancellable?

	public init(
			broadcaster: BTBroadcaster,
			controlChar: BTCharacteristicIdentity,
			feedbackChar: BTCharacteristicIdentity,
			transfomer: T,
			defaultValue: P = P()) {

		//TODO: if characteristic supports write
		let sendControl: ((M) -> M?)? = {
			broadcaster.send(data: $0.pack(), to: controlChar)
			return nil //TODO: if characteristic has notify
		}

		super .init(
			sendControl: sendControl,
			transfomer: transfomer,
			defaultValue: defaultValue)

		//TODO: if characteriastic supports read
		if let data = broadcaster.read(value: feedbackChar), !data.isEmpty {
			self.receiveFeedback(newFeedbackMomento: try? M(unpack: data))
		}
		//TODO: if characteristic has notify
		self.sink = broadcaster.sink(id: id, to: feedbackChar) {data in
			self.receiveFeedback(newFeedbackMomento: try? M(unpack: data))
		}
	}

	public convenience init(
			broadcaster: BTBroadcaster,
			characteristic: BTCharacteristicIdentity,
			transfomer: T,
			defaultValue: P = P()) {
		self.init(
			broadcaster: broadcaster,
			controlChar: characteristic,
			feedbackChar: characteristic,
			transfomer: transfomer,
			defaultValue: defaultValue)
	}

	public convenience init(
			broadcaster: BTBroadcaster,
			characteristic: BTCharacteristicIdentity,
			transfomer: T = BTValueTransformer<P>(),
			defaultValue: P = P()) where P == M {
		self.init(
			broadcaster: broadcaster,
			controlChar: characteristic,
			feedbackChar: characteristic,
			transfomer: transfomer,
			defaultValue: defaultValue)
	}
}
