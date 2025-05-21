import Network
import Foundation
import Combine

public class MDNSDevice: ObservableObject, DeviceIdentifiable {
	public let service: String
	public let id: UUID
	public let endpoint: NWEndpoint

	public init(service: String, endpoint: NWEndpoint, name: String) {
		self.service = service
		self.id = UUID()
		self.endpoint = endpoint
		self.name = name
	}

	public convenience init(preview: String) {
		self.init(
			service: preview,
			endpoint: NWEndpoint.service(name: preview, type: preview, domain: "", interface: nil),
			name: preview)
	}

	@Published public var name: String = ""
	@Published public var advertisedData: String = ""
}

public class MDNSClient: ObservableObject {
	private let browsers: [NWBrowser]
	private var known: [NWEndpoint: MDNSDevice] = [:] {
		didSet {
			devices = known.values.sorted { $0.name < $1.name }
		}
	}

	public init(services: [String]) {
		browsers = services.map { type in
			let parameters = NWParameters()
			parameters.includePeerToPeer = true
			return NWBrowser(for: .bonjour(type: "_\(type)._tcp", domain: nil), using: parameters)
		}

		for browser in browsers {
			browser.stateUpdateHandler = { [weak self] newState in
				self?.handleBrowserStateChange(browser: browser, newState: newState)
			}
			browser.browseResultsChangedHandler = { [weak self] results, _ in
				self?.handleBrowseResultsChange(results: results)
			}
		}
	}

	@Published public var scanning: Bool = false {
		didSet {
			scanning ? startScanning() : stopScanning()
		}
	}

	@Published public private(set) var devices: [MDNSDevice] = []

	private func handleBrowserStateChange(browser: NWBrowser, newState: NWBrowser.State) {
		print("Browser \(browser) changed state to: \(newState)")
	}

	private func handleBrowseResultsChange(results: Set<NWBrowser.Result>) {
		for result in results {
			if case let .service(name, _, _, _) = result.endpoint {
				resolveService(endpoint: result.endpoint, name: name)
			}
		}
	}

	private func startScanning() {
		browsers.forEach { $0.start(queue: DispatchQueue.global()) }
	}

	private func stopScanning() {
		browsers.forEach { $0.cancel() }
	}

	private func resolveService(endpoint: NWEndpoint, name: String) {
		discoverDevice(endpoint: endpoint, name: name, advertisedData: "")
		let connection = NWConnection(to: endpoint, using: NWParameters())
		connection.stateUpdateHandler = { [weak self] newState in
			if case .ready = newState {
				self?.fetchAdvertisedData(connection: connection, endpoint: endpoint, name: name)
			}
		}
		connection.start(queue: DispatchQueue.global())
	}

	fileprivate func discoverDevice(endpoint: NWEndpoint, name: String, advertisedData: String) {
		DispatchQueue.main.async {
			if let existing = self.known[endpoint] {
				existing.name = name
				existing.advertisedData = advertisedData
			}
			else {
				if case let NWEndpoint.service(_, type, _, _) = endpoint {
					let startIndex = type.index(type.startIndex, offsetBy: 1) // Constant index
					let endIndex = type.firstIndex(of: ".")!
					let service = type[startIndex..<endIndex] // Extract substring
					let device = MDNSDevice(
						service: String(service),
						endpoint: endpoint,
						name: name)
					device.advertisedData = advertisedData
					self.known[endpoint] = device
				}
			}
		}
	}
	
	private func fetchAdvertisedData(connection: NWConnection, endpoint: NWEndpoint, name: String) {
		connection.receive(minimumIncompleteLength: 0, maximumLength: 1024) { data, _, _, _ in
			var advertisedData = ""
			if let data = data, !data.isEmpty {
				if let text = String(data: data, encoding: .utf8) {
					advertisedData = text
				} else {
					advertisedData = data.map { String(format: "%02x", $0) }
						.joined(separator: "")
				}
			}
			self.discoverDevice(endpoint: endpoint, name: name, advertisedData: advertisedData)
			connection.cancel()
		}
	}
}
