//
//  BTUART.swift
//  BLEByJove
//
//  Created by David Giovannini on 12/5/22.
//

import Foundation
import Collections

/// Serializes request/response traffic over a pair of BLE characteristics.
///
/// `BTUART` is main-actor isolated because its broadcaster is a CoreBluetooth-backed object that
/// is intentionally main-actor isolated. Request ordering is still explicit: only the first queued
/// request is transmitted, and a structured-concurrency timeout advances the queue if no response
/// arrives.
@MainActor
public final class BTUART {
    private struct Request {
        let key: Int
        let data: Data
        let response: ((Data?) -> Void)?
        let timeout: Duration
        let dropKey: String?
    }

    private let id = UUID()
    private let controlChar: BTCharacteristicIdentity
    private let feedbackChar: BTCharacteristicIdentity
    private let broadcaster: any BTBroadcaster

    private var sink: BTSubscription?
    private var keyFactory = 0
    private var queue: OrderedDictionary<Int, Request> = [:]
    private var timeoutTask: Task<Void, Never>?

    public init(
        _ controlChar: BTCharacteristicIdentity,
        _ feedbackChar: BTCharacteristicIdentity,
        _ broadcaster: any BTBroadcaster
    ) {
        self.feedbackChar = feedbackChar
        self.controlChar = controlChar
        self.broadcaster = broadcaster
    }

    isolated deinit {
        timeoutTask?.cancel()
        sink?.cancel()
    }

    public func connect() {
        sink?.cancel()
        sink = broadcaster.sink(id: id, to: feedbackChar) { [weak self] data in
            self?.receiveFeedback(data)
        }
    }

    public func disconnect() {
        sink?.cancel()
        sink = nil
        timeoutTask?.cancel()
        timeoutTask = nil

        let pending = queue.values
        queue.removeAll()
        for request in pending {
            request.response?(nil)
        }
    }

    public func call<T>(
        _ data: Data?,
        timeout: Int = 100,
        dropKey: String? = nil,
        _ parse: @escaping (Data) -> T?
    ) async -> T? {
        guard let data, !data.isEmpty else { return nil }
        let response = await withCheckedContinuation { continuation in
            call(data, timeout: timeout, dropKey: dropKey) { data in
                continuation.resume(returning: data)
            }
        }
        guard let response else { return nil }
        return parse(response)
    }

    public func call(
        _ data: Data?,
        timeout: Int = 100,
        dropKey: String? = nil,
        response: ((Data?) -> Void)? = nil
    ) {
        guard let data, !data.isEmpty else {
            response?(nil)
            return
        }

        let duration = Duration.milliseconds(timeout)

        if let dropKey,
           let replaceable = queue.values.dropFirst().first(where: { $0.dropKey == dropKey }) {
            replaceable.response?(nil)
            queue[replaceable.key] = Request(
                key: replaceable.key,
                data: data,
                response: response,
                timeout: duration,
                dropKey: dropKey
            )
            return
        }

        keyFactory &+= 1
        let key = keyFactory
        queue[key] = Request(
            key: key,
            data: data,
            response: response,
            timeout: duration,
            dropKey: dropKey
        )

        if queue.count == 1 {
            broadcastCurrent()
        }
    }

    private func broadcastCurrent() {
        guard let request = queue.values.first else { return }

        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: request.timeout)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.receiveTimeout(request.key)
        }

        broadcaster.send(data: request.data, to: controlChar, confirmed: { _ in })
    }

    private func receiveFeedback(_ data: Data?) {
        guard let key = queue.keys.first, let request = queue[key] else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        queue.removeValue(forKey: key)
        request.response?(data)
        broadcastCurrent()
    }

    private func receiveTimeout(_ key: Int) {
        guard let request = queue[key] else { return }
        let wasCurrent = queue.keys.first == key
        queue.removeValue(forKey: key)
        if wasCurrent {
            timeoutTask = nil
        }
        request.response?(nil)
        if wasCurrent {
            broadcastCurrent()
        }
    }
}
