import Network
import Foundation
import Observation

/// Bonjour device discovery used alongside BLE discovery.
///
/// Browsers are recreated for each scanning session because `NWBrowser.cancel()` is terminal.
/// All browser and connection callbacks run on the main queue so observable device state has the
/// same isolation model as the Bluetooth scanners.
@MainActor
@Observable
public final class MDNSClient: DeviceScanner {
    private let services: [String]
    private var browsers: [String: NWBrowser] = [:]
    private var endpointsByService: [String: Set<NWEndpoint>] = [:]
    private var known: [NWEndpoint: MDNSDevice] = [:]
    private var resolutionConnections: [NWEndpoint: NWConnection] = [:]

    public private(set) var devices: [MDNSDevice] = []

    public init(services: [String]) {
        self.services = services
    }

    public var scanning = false {
        didSet {
            scanning ? startScanning() : stopScanning()
        }
    }

    private func publishDevices() {
        devices = known.values.sorted { $0.name < $1.name }
    }

    private func makeBrowser(for service: String) -> NWBrowser {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_\(service)._tcp", domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { _ in }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated {
                self?.handleBrowseResultsChange(service: service, results: results)
            }
        }
        return browser
    }

    private func startScanning() {
        guard browsers.isEmpty else { return }
        for service in services {
            let browser = makeBrowser(for: service)
            browsers[service] = browser
            browser.start(queue: .main)
        }
    }

    private func stopScanning() {
        for browser in browsers.values {
            browser.cancel()
        }
        browsers.removeAll()
        endpointsByService.removeAll()
        known.removeAll()
        resolutionConnections.values.forEach { $0.cancel() }
        resolutionConnections.removeAll()
        publishDevices()
    }

    private func handleBrowseResultsChange(service: String, results: Set<NWBrowser.Result>) {
        let endpoints = Set(results.map(\.endpoint))
        endpointsByService[service] = endpoints

        let allVisible = endpointsByService.values.reduce(into: Set<NWEndpoint>()) { partial, set in
            partial.formUnion(set)
        }
        known = known.filter { allVisible.contains($0.key) }
        for endpoint in Array(resolutionConnections.keys) where !allVisible.contains(endpoint) {
            resolutionConnections.removeValue(forKey: endpoint)?.cancel()
        }

        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            resolveService(endpoint: result.endpoint, name: name, service: service)
        }
        publishDevices()
    }

    private func resolveService(endpoint: NWEndpoint, name: String, service: String) {
        discoverDevice(endpoint: endpoint, name: name, service: service, advertisedData: "")

        guard resolutionConnections[endpoint] == nil else { return }

        let connection = NWConnection(to: endpoint, using: NWParameters())
        resolutionConnections[endpoint] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }
            MainActor.assumeIsolated {
                switch state {
                case .ready:
                    self?.fetchAdvertisedData(
                        connection: connection,
                        endpoint: endpoint,
                        name: name,
                        service: service
                    )
                case .failed, .cancelled:
                    self?.resolutionConnections.removeValue(forKey: endpoint)
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func discoverDevice(endpoint: NWEndpoint, name: String, service: String, advertisedData: String) {
        if let existing = known[endpoint] {
            existing.name = name
            existing.advertisedData = advertisedData
        } else {
            let device = MDNSDevice(service: service, endpoint: endpoint, name: name)
            device.advertisedData = advertisedData
            known[endpoint] = device
        }
        publishDevices()
    }

    private func fetchAdvertisedData(
        connection: NWConnection,
        endpoint: NWEndpoint,
        name: String,
        service: String
    ) {
        connection.receive(minimumIncompleteLength: 0, maximumLength: 1024) { [weak self] data, _, _, _ in
            let advertisedData: String
            if let data, !data.isEmpty {
                advertisedData = String(data: data, encoding: .utf8)
                    ?? data.map { String(format: "%02x", $0) }.joined()
            } else {
                advertisedData = ""
            }

            MainActor.assumeIsolated {
                self?.discoverDevice(
                    endpoint: endpoint,
                    name: name,
                    service: service,
                    advertisedData: advertisedData
                )
                self?.resolutionConnections.removeValue(forKey: endpoint)
            }
            connection.cancel()
        }
    }
}
