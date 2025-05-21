//
//  RequestThrottler.swift
//  BLEByJove
//
//  Created by David Giovannini on 5/21/25.
//

import Foundation

public class RequestThrottler {
	public enum RequestResult {
		case dropped
		case failure(Error)
		case success(Data)
	}

	private var lastRequestTime: Date?
	private var pendingRequest: ((URLRequest, ((RequestResult) -> Void)?))?
	private let queue = DispatchQueue(label: "RequestThrottlerQueue")

	public init() {
	}

	public func sendRequest(url: URL, completion: ((RequestResult) -> Void)? = nil) {
		sendRequest(request: URLRequest(url: url), completion: completion)
	}

	public func sendRequest(request: URLRequest, completion: ((RequestResult) -> Void)? = nil) {
		queue.async {
			let now = Date()
			if let lastTime = self.lastRequestTime, now.timeIntervalSince(lastTime) < 1.0 {
				if let completion = self.pendingRequest?.1 {
					completion(.dropped)
				}
				self.pendingRequest = (request, completion)
				return
			}

			self.lastRequestTime = now
			self.execute(request, completion)
			DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
				self.queue.async {
					if let pending = self.pendingRequest {
						self.pendingRequest = nil
						self.execute(pending.0, pending.1)
					}
				}
			}
		}
	}

	private func execute(_ request: URLRequest, _ completion: ((RequestResult) -> Void)?) {
		URLSession.shared.dataTask(with: request) { data, response, error in
			if let completion = completion {
				if let error = error {
					completion(.failure(error))
				}
				else if let data = data {
					completion(.success(data))
				}
				else {
					completion(.dropped)
				}
			}
		}.resume()
	}
}
