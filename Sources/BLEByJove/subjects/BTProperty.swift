//
//  BTProperty.swift
//  BLEByJove
//
//  Created by David Giovannini on 3/24/25
//

import Foundation

@MainActor
public class BTProperty<T: ValueTransforming>: TransformedProperty<T>
where T.P: Equatable, T.M: Equatable, T.M: BTSerializable {
    private var sink: BTSubscription?

    public init(
        broadcaster: any BTBroadcaster,
        controlChar: BTCharacteristicIdentity,
        feedbackChar: BTCharacteristicIdentity,
        transfomer: T,
        defaultValue: P = P()
    ) {
        let sendControl: ((M) -> M?)? = {
            broadcaster.send(data: $0.pack(), to: controlChar)
            return nil
        }

        super.init(
            sendControl: sendControl,
            transfomer: transfomer,
            defaultValue: defaultValue
        )

        if let data = broadcaster.read(value: feedbackChar), !data.isEmpty {
            receiveFeedback(newFeedbackMomento: try? M(unpack: data))
        }

        sink = broadcaster.sink(id: id, to: feedbackChar) { [weak self] data in
            self?.receiveFeedback(newFeedbackMomento: try? M(unpack: data))
        }
    }

    public convenience init(
        broadcaster: any BTBroadcaster,
        characteristic: BTCharacteristicIdentity,
        transfomer: T,
        defaultValue: P = P()
    ) {
        self.init(
            broadcaster: broadcaster,
            controlChar: characteristic,
            feedbackChar: characteristic,
            transfomer: transfomer,
            defaultValue: defaultValue
        )
    }

    public convenience init(
        broadcaster: any BTBroadcaster,
        characteristic: BTCharacteristicIdentity,
        transfomer: T = BTValueTransformer<P>(),
        defaultValue: P = P()
    ) where P == M {
        self.init(
            broadcaster: broadcaster,
            controlChar: characteristic,
            feedbackChar: characteristic,
            transfomer: transfomer,
            defaultValue: defaultValue
        )
    }
}
