//
//  withObservationTracking.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation
import Observation

public final class ObserveToken {
    private actor State {
        private var cancelled = false
        func setCancelled() { cancelled = true }
        func isCancelled() -> Bool { cancelled }
    }
    private let state = State()

    public init() {}

    public func cancel() {
        Task { await state.setCancelled() }
    }

    func isCancelled() async -> Bool {
        await state.isCancelled()
    }
}

@discardableResult
public func observe<O: AnyObject, S: AnyObject, V>(
		for dest: O,
		with src: S,
		_ path: KeyPath<S, V>,
		initialPush: Bool = true,
		onChange: @escaping (O, S, V) -> Void) -> ObserveToken {
	let token = ObserveToken()
	func track(dest: O?, src: S?) {
		guard let dest, let src else { return }
		withObservationTracking({
			_ = src[keyPath: path]
		}, onChange: { [weak weakDest = dest, weak weakSrc = src] in
			Task {
				guard let strongDest = weakDest, let strongSrc = weakSrc else { return }
				if await token.isCancelled() { return }
				await MainActor.run {
					let value = strongSrc[keyPath: path]
					onChange(strongDest, strongSrc, value)
				}
				if await token.isCancelled() { return }
				track(dest: strongDest, src: strongSrc)
			}
		})
	}
	if initialPush {
		Task {
			if await token.isCancelled() { return }
			await MainActor.run {
				let value = src[keyPath: path]
				onChange(dest, src, value)
			}
			if await token.isCancelled() { return }
			track(dest: dest, src: src)
		}
	} else {
		track(dest: dest, src: src)
	}
	return token
}
