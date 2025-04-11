//
//  BTUART.swift
//  BLEByJove
//
//  Created by David Giovannini on 12/5/22.
//

import Foundation
import Combine
import Collections

//TODO: continue to implement expected behaviors
public final actor BTUART {
	private let id = CombineIdentifier()
	private let controlChar: BTCharacteristicIdentity
	private let feedbackChar: BTCharacteristicIdentity
	private let broadcaster: BTBroadcaster

	private var sink: AnyCancellable?
	private var keyFactory: Int = 0
	private var queue: OrderedDictionary<Int, (Data, ((Data?)->())?, Int, String?)> = [:]

	public init(_ controlChar: BTCharacteristicIdentity, _ feedbackChar: BTCharacteristicIdentity, _ broadcaster: BTBroadcaster) {
		self.feedbackChar = feedbackChar
		self.controlChar = controlChar
		self.broadcaster = broadcaster
	}

	public func connect() {
		self.sink = broadcaster.sink(id: id, to: feedbackChar) { [weak self] data in
			Task {
				await self?.receiveFeedback(data)
			}
		}
	}

	public func disconnect() {
		self.sink?.cancel()
	}

	public func call<T>(_ data: Data?, timeout: Int = 100, dropKey: String? = nil, _ parse: (Data)->T?) async -> T? {
		if let data, data.isEmpty == false {
			let response = await withCheckedContinuation { continuation in
				call(data, timeout: timeout, dropKey: dropKey) { data in
					return continuation.resume(with: .success(data))
				}
			}
			if let response {
				if let value = parse(response) {
					return value
				}
			}
		}
		return nil
	}

	public func call(_ data: Data?, timeout: Int = 100, dropKey: String? = nil, response: ((Data?)->())? = nil) {
		if let data, data.isEmpty == false {
			if let dropKey {
				for element in queue {
					if element.value.3 == dropKey {
						if (queue.index(forKey: element.key) != 0) {
							element.value.1?(nil) //timeout
							queue[element.key] = (data, response, timeout, dropKey)
							return
						}
					}
				}
			}
			self.keyFactory += 1
			let key = keyFactory
			queue[key] = (data, response, timeout, dropKey)
			if queue.count == 1 {
				broadcast(key, data, response, timeout)
			}
		}
		else {
			response?(nil)
		}
	}

	private func broadcast(_ key: Int, _ data: Data, _ response: ((Data?)->())?, _ timeout: Int) {
		DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeout)) {
			Task { await
				self.receiveTimout(key)
			}
		}
		broadcaster.send(data: data, to: controlChar, confirmed: { _ in })
	}

	private func receiveFeedback(_ data: Data?) {
		if queue.isEmpty == false {
			let finalied = queue.removeFirst().value
			finalied.1?(data)
		}
		if queue.isEmpty == false {
			let next = queue.elements[0]
			broadcast(next.key, next.value.0, next.value.1, next.value.2)
		}
	}

	private func receiveTimout(_ key: Int) {
		if let finalied = self.queue[key] {
			let idx = self.queue.index(forKey: key)
			self.queue.removeValue(forKey: key)
			finalied.1?(nil)
			if ( idx == 0 && queue.isEmpty == false) {
				let next = queue.elements[0]
				broadcast(next.key, next.value.0, next.value.1, next.value.2)
			}
		}
	}
}
