//TODO: I cannot find the recipe for an example playground as part of a swift package!

import SwiftUI
import BLEByJove

let client = BTClient(services: [CircuitCube.Service])

struct BLEListView: View {
	@ObservedObject private var client: BTClient

	init(client: BTClient) {
		self.client = client
	}

	var body: some View {
		NavigationStack {
			Group {
				if client.devices.isEmpty {
					Text("No devices found.")
				}
				else {
					List(client.devices) { device in
						let facility = facilities.implementation(for: device)
						NavigationLink(value: device.id) {
							Text(device.name)
						}
					}
				}
			}
			.onAppear() {
				client.scanning = true
			}
			.onDisappear() {
				client.scanning = false
			}
			.navigationDestination(for: FacilityEntry.self) { device in
				Text(device.name)
			}
		}
	}
}

@main
struct App: App {
	private let client = BTClient(services: [CircuitCube.Service])

	@SceneBuilder var body: some Scene {
		WindowGroup {
			BLEListView(client: client)
		}
	}
}
