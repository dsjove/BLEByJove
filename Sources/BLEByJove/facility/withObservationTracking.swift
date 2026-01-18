//
//  withObservationTracking.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation
import Observation

public func withObservationTracking<O: AnyObject, S: AnyObject, V>(
		for dest: O,
		with src: S,
		value path: KeyPath<S, V>,
		initialPush: Bool = true,
		onChange: @escaping (O, S, V) -> Void) {
	func track(dest: O?, src: S?) {
		guard let dest, let src else { return }
		withObservationTracking({
			_ = src[keyPath: path]
		}, onChange: { [weak weakDest = dest, weak weakSrc = src] in
			guard let strongDest = weakDest, let strongSrc = weakSrc else { return }
			Task { @MainActor in
				let value = strongSrc[keyPath: path]
				onChange(strongDest, strongSrc, value)
				track(dest: strongDest, src: strongSrc)
			}
		})
	}
	if initialPush {
		Task { @MainActor in
			let value = src[keyPath: path]
			onChange(dest, src, value)
			track(dest: dest, src: src)
		}
	} else {
		track(dest: dest, src: src)
	}
}
