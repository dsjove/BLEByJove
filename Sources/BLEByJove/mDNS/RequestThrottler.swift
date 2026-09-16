//
//  RequestThrottler.swift
//  BLEByJove
//
//  Created by David Giovannini on 5/21/25.
//

import Foundation

/// Starts at most one request per interval and coalesces pending traffic to the newest request.
/// The public API remains callback-based so existing synchronous control-property callers do not
/// need to own Tasks; networking itself uses URLSession's async API internally.
public final class RequestThrottler: Sendable {
    public enum RequestResult: @unchecked Sendable {
        case dropped
        case failure(Error)
        case success(Data)
    }

    public typealias Loader = @Sendable (URLRequest) async throws -> Data
    public typealias Completion = @Sendable (RequestResult) -> Void

    private let state: State

    public init(
        minimumInterval: Duration = .seconds(1),
        loader: @escaping Loader = { request in
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        }
    ) {
        state = State(minimumInterval: minimumInterval, loader: loader)
    }

    public func sendRequest(url: URL, completion: Completion? = nil) {
        sendRequest(request: URLRequest(url: url), completion: completion)
    }

    public func sendRequest(request: URLRequest, completion: Completion? = nil) {
        Task {
            await state.enqueue(request: request, completion: completion)
        }
    }

    private actor State {
        private struct Pending {
            let request: URLRequest
            let completion: Completion?
        }

        private let clock = ContinuousClock()
        private let minimumInterval: Duration
        private let loader: Loader
        private var lastStart: ContinuousClock.Instant?
        private var pending: Pending?
        private var wakeTask: Task<Void, Never>?

        init(minimumInterval: Duration, loader: @escaping Loader) {
            self.minimumInterval = minimumInterval
            self.loader = loader
        }

        func enqueue(request: URLRequest, completion: Completion?) {
            let now = clock.now
            guard let lastStart else {
                start(Pending(request: request, completion: completion), at: now)
                return
            }

            let elapsed = lastStart.duration(to: now)
            if elapsed >= minimumInterval {
                start(Pending(request: request, completion: completion), at: now)
                return
            }

            pending?.completion?(.dropped)
            pending = Pending(request: request, completion: completion)
            scheduleWake(after: minimumInterval - elapsed)
        }

        private func start(_ item: Pending, at instant: ContinuousClock.Instant) {
            lastStart = instant
            Task { [loader] in
                do {
                    item.completion?(.success(try await loader(item.request)))
                } catch {
                    item.completion?(.failure(error))
                }
            }
        }

        private func scheduleWake(after delay: Duration) {
            guard wakeTask == nil else { return }
            wakeTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                await self?.flushPending()
            }
        }

        private func flushPending() {
            wakeTask = nil
            guard let pending else { return }
            self.pending = nil
            start(pending, at: clock.now)
        }
    }
}
