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
		value: KeyPath<S, V>,
		initialPush: Bool = true,
		onChange: @escaping (O, S, V) -> Void) {
	func track(dest: O?, src: S?) {
		guard let dest, let src else { return }
		withObservationTracking(
			{ _ = src[keyPath: value] },
			onChange: { [weak weakDest = dest, weak weakSrc = src] in
				guard let strongDest = weakDest, let strongSrc = weakSrc else { return }
				onChange(strongDest, strongSrc, strongSrc[keyPath: value])
				track(dest: strongDest, src: strongSrc)
			}
		)
	}
	if initialPush {
		onChange(dest, src, src[keyPath: value])
	}
	track(dest: dest, src: src)
}

