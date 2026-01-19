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
public final class FacilityRepository: RFIDConsumer {
	public private(set) var scanners: [any DeviceScanning] = []

	private let createFacilities: (any DeviceIdentifiable) -> [any Facility]
	private var facilitiesByDeviceID: [ObjectIdentifier : [UUID: [FacilityEntry]]] = [:]
	public private(set) var facilities: [FacilityEntry] = []

	private var rfidTokensByDeviceID: [UUID: [ObserveToken]] = [:]

	public init(createFacilities: @escaping (any DeviceIdentifiable) -> [any Facility]) {
		self.createFacilities = createFacilities
	}

	public func addScanner<S: DeviceScanner>(_ scanner: S) {
		scanners.append(scanner)
		observe(for: self, with: scanner, \.devices) { this, scanner, _ in
			this.sync(from: scanner)
		}
	}

	public func setScanning(_ scanning: Bool) {
		for scanner in scanners {
			scanner.scanning = scanning
		}
	}

	private func sync(from scanner: any DeviceScanner) {
		let scannerDevices = scanner.anyDevices()
		let scannerDeviceIds = Set(scannerDevices.map(\.id))
		var scope = facilitiesByDeviceID[ObjectIdentifier(scanner)] ?? [:]

		// Given never seen device before
		for device in scannerDevices where scope[device.id] == nil {
			// Create the facilities
			let newFacilities = createFacilities(device)
			scope[device.id] = newFacilities.map { .init($0, id: $0.id) }
			// Observe RFIDs if we can
			for facility in newFacilities {
				if let rfidProducer = facility as? (AnyObject & RFIDProducing) {
					observeRFID(rfidProducer, deviceID: device.id)
				}
			}
		}

		// Observe RFID producers
		func observeRFID<P: AnyObject & RFIDProducing>(_ rfidProducer: P, deviceID: UUID) {
			let token = observe(for: self, with: rfidProducer, P.rfid) { this, _, value in
				this.didDetectRFID(value)
			}
			var tokensForDevice = rfidTokensByDeviceID[deviceID] ?? []
			tokensForDevice.append(token)
			rfidTokensByDeviceID[deviceID] = tokensForDevice
		}

		// If devices have disappeared
		for deviceID in scope.keys where !scannerDeviceIds.contains(deviceID) {
			// Remove all facilities for the device
			scope.removeValue(forKey: deviceID)
			// Cancel all tokens for the device
			if let tokens = rfidTokensByDeviceID.removeValue(forKey: deviceID) {
				for token in tokens { token.cancel() }
			}
		}
		facilitiesByDeviceID[ObjectIdentifier(scanner)] = scope
		rebuildFacilitiesSorted()
	}

	public func didDetectRFID(_ detection: RFIDDetection) {
		for scanner in scanners {
			( (scanner as? RFIDConsumer) )?.didDetectRFID(detection)
		}
	}

	private func rebuildFacilitiesSorted() {
		let all = facilitiesByDeviceID.values.flatMap { $0.values.flatMap { $0 } }
		facilities = all.sorted { lhs, rhs in
			let lhsName = lhs.value.name
			let rhsName = rhs.value.name
			let cmp: ComparisonResult = lhsName.localizedStandardCompare(rhsName)
			if cmp != .orderedSame {
				return cmp == .orderedAscending
			}
			return lhs.id.uuidString < rhs.id.uuidString
		}
	}
}
