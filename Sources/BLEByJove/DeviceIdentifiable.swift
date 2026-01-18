import Foundation
import Observation
import SBJKit

// MARK: - DeviceIdentifiable

public enum ConnectionState: String {
	case disconnected
	case connecting
	case connected
}

public protocol DeviceIdentifiable: Identifiable {
	var id: UUID { get }
	var name: String { get }
}

// MARK: - DeviceScanning / DeviceScanner

public protocol DeviceScanning: AnyObject {
	var scanning: Bool { get set }
}

protocol DeviceScanning2: DeviceScanning {
	func snapshotDevices() -> [any DeviceIdentifiable]
	func startObservingDevices(onChange: @escaping () -> Void)
}

protocol DeviceScanner: DeviceScanning2 {
	associatedtype Device: DeviceIdentifiable
	var devices: [Device] { get }
}

extension DeviceScanner {
	func snapshotDevices() -> [any DeviceIdentifiable] {
		devices.map { $0 as any DeviceIdentifiable }
	}

	func startObservingDevices(onChange: @escaping () -> Void) {
		func track() {
			withObservationTracking(
				{ _ = devices },
				onChange: {
					onChange()
					track()
				}
			)
		}
		track()
	}
}

// MARK: - Facility

public struct FacilityCategory: Hashable, Sendable {
	let rawValue: String
	public init(_ rawValue: String) {
		self.rawValue = rawValue
	}
}

public protocol Facility: Identifiable {
	var id: UUID { get }

	var category: FacilityCategory { get }
	var name: String { get }
	var image: ImageName { get }

	var connectionState: ConnectionState { get }
	var heartBeat: Int { get }

	func connect()
	func fullStop()
	func disconnect()

	var battery: Double? { get }
}

public extension Facility {
	var heartBeat: Int { connectionState == .connected ? 0 : -1 }

	var battery: Double? { nil }
}

// MARK: - FacilityFactory

@Observable
final class FacilityRepository{
	private let facilitiesForDevice: (any DeviceIdentifiable) -> [any Facility]
	private var facilitiesByDeviceID: [UUID: [any Facility]] = [:]

	private(set) var scanners: [any DeviceScanning] = []
	private(set) var facilities: [any Facility] = []

	public init(facilitiesForDevice: @escaping (any DeviceIdentifiable) -> [any Facility]) {
		self.facilitiesForDevice = facilitiesForDevice
	}

	public func addScanner(_ scanner: any DeviceScanning2) {
		scanners.append(scanner)
		sync(from: scanner)
		scanner.startObservingDevices { [weak self, weak scanner] in
			guard let self, let scanner else { return }
			self.sync(from: scanner)
		}
	}

	public func setScanning(_ scanning: Bool) {
		for scanner in scanners {
			scanner.scanning = scanning
		}
	}

	private func sync(from scanner: any DeviceScanning2) {
		let devices = scanner.snapshotDevices()
		let currentIDs = Set(devices.map(\.id))
		// Add new devices
		for device in devices where facilitiesByDeviceID[device.id] == nil {
			facilitiesByDeviceID[device.id] = facilitiesForDevice(device)
		}
		// Remove devices that disappeared
		for knownID in facilitiesByDeviceID.keys where !currentIDs.contains(knownID) {
			facilitiesByDeviceID.removeValue(forKey: knownID)
		}
		rebuildFacilitiesSorted()
	}

	private func rebuildFacilitiesSorted() {
		let all = facilitiesByDeviceID.values.flatMap { $0 }
		facilities = all.sorted {
			let cmp = $0.name.localizedStandardCompare($1.name)
			if cmp != .orderedSame {
				return cmp == .orderedAscending
			}
			return $0.id.uuidString < $1.id.uuidString
		}
	}
}

// MARK: - Concrete scanner compatible with FacilityFactory

struct DemoDevice: DeviceIdentifiable {
	let id: UUID
	let name: String
}

@Observable
final class DemoScanner: DeviceScanner {
	private(set) var devices: [DemoDevice] = []

	var scanning: Bool = false {
		didSet { scanning ? startDemo() : stopDemo() }
	}

	private var timer: Timer?

	private func startDemo() {
		if devices.isEmpty {
			devices = [DemoDevice(id: UUID(), name: "Demo Device A")]
		}

		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
			guard let self else { return }

			if self.devices.count < 3 {
				let letter = Character(UnicodeScalar(65 + self.devices.count)!) // A, B, C
				self.devices.append(
					DemoDevice(id: UUID(), name: "Demo Device \(letter)")
				)
			} else {
				self.devices.removeFirst()
			}
		}
	}

	private func stopDemo() {
		timer?.invalidate()
		timer = nil
		devices.removeAll()
	}
}

// MARK: - Example Facility implementation

extension FacilityCategory {
	static let demo = FacilityCategory("demo")
	static let pump = FacilityCategory("pump")
	static let lighting = FacilityCategory("lighting")
}

@Observable
final class DemoFacility: Facility {
	let id: UUID
	let category: FacilityCategory = .demo
	let name: String
	let image: ImageName = .system("moon.stars")

	private(set) var connectionState: ConnectionState = .disconnected
	private(set) var heartBeat: Int = 0
	private(set) var battery: Double?

	init(id: UUID = UUID(), name: String, battery: Double? = nil) {
		self.id = id
		self.name = name
		self.battery = battery
	}

	func connect() { connectionState = .connected }
	func fullStop() { }
	func disconnect() { connectionState = .disconnected }
}

// MARK: - Wiring example
func sample() {
	let factory = FacilityRepository { device in
		[DemoFacility(name: "Facility for \(device.name)", battery: 0.75)]
	}
	factory.addScanner(DemoScanner())
	factory.setScanning(true)
}
