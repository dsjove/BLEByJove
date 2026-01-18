//
//  FacilityRepository.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/18/26.
//

import Foundation
import Observation
import SBJKit

public typealias FacilityEntry = Identified<any Facility>

@Observable
public final class FacilityRepository {
	private let facilitiesForDevice: (any DeviceIdentifiable) -> [any Facility]
	private var facilitiesByDeviceID: [UUID: [any Facility]] = [:]

	public private(set) var scanners: [any DeviceScanning] = []
	public private(set) var facilities: [any Facility] = []
	public var facilityEntries: [FacilityEntry] { facilities.map({FacilityEntry($0)}) }

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

extension FacilityRepository: RFIDConsumer {
	public func didDetectRFID(_ detection: RFIDDetection) {
		for scanner in scanners {
			( (scanner as? RFIDConsumer) )?.didDetectRFID(detection)
		}
	}
}
