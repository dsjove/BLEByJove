//
//  ArduinoR4MatrixView.swift
//  Infrastructure
//
//  Created by David Giovannini on 3/23/25.
//

import SwiftUI

public struct ArduinoR4MatrixView: View {
	public enum Interactive {
		case none
		case draw
		case scroll
	}

	private var value: ArduinoR4Matrix
	private var interactive: Interactive
	private let action: (ArduinoR4Matrix) -> Void

	@State private var drawing: Bool?
	@State private var scrolling: CGPoint?

	@Environment(\.isEnabled) private var isEnabled: Bool

	public init(
		value: ArduinoR4Matrix,
		interactive: Interactive = .none,
		action: @escaping (ArduinoR4Matrix) -> Void = { _ in}) {
			self.value = value
			self.interactive = interactive
			self.action = action
	}

	//TODO: make prettier :-)
	public var body: some View {
		let columnCount = Double(value.columns)
		let rowCount = Double(value.rows)
		let ratio = columnCount / rowCount
		let backColor = Color(red: 0.0, green: 0.0, blue: 0.5)
		GeometryReader { geom in
			let w = min(geom.size.height / rowCount, geom.size.width / columnCount)
			let width = w * columnCount
			let height = w * rowCount
			Grid(alignment: Alignment.center, horizontalSpacing: 0, verticalSpacing: 0) {
				ForEach(0..<value.rows, id: \.self) { r in
					GridRow {
						ForEach(0..<value.columns, id: \.self) { c in
							ZStack {
								RoundedRectangle(cornerRadius: w * 0.05)
									.fill(Color.gray)
									.border(Color.white, width: 2)
									.frame(width: w * 0.4, height: w)
									.rotationEffect(.degrees(45.0))
									.padding(0)
								Circle()
									.fill(RadialGradient(
										gradient: Gradient(colors: [
											Color.red.opacity(0.75),
											Color.red,
											Color.yellow]),
										center: .center,
										startRadius: 100,
										endRadius: 0))
									.frame(width: w, height: w)
									.opacity(value[r, c] ? 1.0 : 0.0)
								//let i = r * value.columns + c
								//Text("\(i/32).\(i % 32)")
							}
						}
					}
				}
			}
			.frame(width: width, height: height)
			.background(backColor)
#if !os(tvOS)
			.gesture(DragGesture(minimumDistance: 0)
				.onChanged { drag in
					if interactive == .scroll {
						if let scrolling {
							let dx = drag.location.x - scrolling.x
							let dy = drag.location.y - scrolling.y
							if abs(dx) > w / 2.0 {
								self.scrolling = drag.location
								var s = value
								s.scroll(true, dx > 0 ? 1 : -1, nil)
								action(s)
							}
							if abs(dy) > w / 2.0 {
								self.scrolling = drag.location
								var s = value
								s.scroll(false, dy > 0 ? 1 : -1, nil)
								action(s)
							}
						}
						else {
							scrolling = drag.location
						}
					}
					else if interactive == .draw {
						let c = Int(drag.location.x / w)
						let r = Int(drag.location.y / w)
						if (r < 0 || r >= value.rows || c < 0 || c >= value.columns) {
							return
						}
						let current = value[r, c]
						if drawing == nil {
							drawing = !current
						}
						if let drawing, current != drawing {
							var s = value
							s[r, c] = drawing
							action(s)
						}
					}
				}
				.onEnded({ _ in
					drawing = nil
					scrolling = nil
				}))
#else
	//TODO: implement tvOS
#endif
		}
		.opacity(isEnabled ? 1.0 : 0.5)
		.aspectRatio(ratio, contentMode: .fit)
	}
}

#Preview {
	let matrix = {
		var a = ArduinoR4Matrix()
		a.fill(.random)
		return a
	}
	ArduinoR4MatrixView(value: matrix())
		.background(Color.mint)
}
