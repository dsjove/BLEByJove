//
//  RequestThrottler.swift
//  BLEByJove
//
//  Created by David Giovannini on 5/21/25.
//

import Foundation

public class RequestThrottler {
	private var lastRequestTime: Date?
	private var pendingRequest: URLRequest?
	private let queue = DispatchQueue(label: "RequestThrottlerQueue")

	public init() {
	}

	public func sendRequest(url: URL) {
		queue.async {
			let now = Date()
			let request = URLRequest(url: url)
			if let lastTime = self.lastRequestTime, now.timeIntervalSince(lastTime) < 1.0 {
				self.pendingRequest = request
				return
			}

			self.lastRequestTime = now
			self.execute(request)
			DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
				self.queue.async {
					if let pending = self.pendingRequest {
						self.pendingRequest = nil
						self.execute(pending)
					}
				}
			}
		}
	}

	private func execute(_ request: URLRequest) {
		URLSession.shared.dataTask(with: request).resume()
	}
}
