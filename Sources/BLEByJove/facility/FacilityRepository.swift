//
//  FacilityRepository.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation
import Observation
import SBJKit

@Observable
final class FacilityRepository {
	private let facilitiesForDevice: (any DeviceIdentifiable) -> [any Facility]
	private var facilitiesByDeviceID: [UUID: [any Facility]] = [:]

	private(set) var scanners: [any DeviceScanning] = []
	private(set) var facilities: [any Facility] = []

	public init(facilitiesForDevice: @escaping (any DeviceIdentifiable) -> [any Facility]) {
		self.facilitiesForDevice = facilitiesForDevice
	}

	public func addScanner<S: DeviceScanner>(_ scanner: S) {
		scanners.append(scanner)
		withObservationTracking(for: self, with: scanner, value: \.devices)
		{ this, scanner, _ in
			this.sync(from: scanner)
		}
	}

	public func setScanning(_ scanning: Bool) {
		for scanner in scanners {
			scanner.scanning = scanning
		}
	}

	private func sync(from scanner: any DeviceScanner) {
		let devices = scanner.anyDevices()
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
