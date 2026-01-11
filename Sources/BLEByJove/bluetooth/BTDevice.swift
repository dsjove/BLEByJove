//
//  BTDevice.swift
//  BLEByJove
//
//  Created by David Giovannini on 6/30/21.
//

import Foundation
import Combine
import CoreBluetooth

public protocol DeviceIdentifiable: ObservableObject, Identifiable {
	var id: UUID { get }
	var name: String { get }
}

public enum ConnectionState: String {
	case disconnected
	case connecting
	case connected
}

public class BTDevice: NSObject, ObservableObject, DeviceIdentifiable {
	private let peripheral : CBPeripheral?
	private let makeConnection: (Bool) ->()

	private var characteristics: [String: CBCharacteristic] = [:]
	private var notifyActivating: Set<String> = []
	private var distribute: [CombineIdentifier: [String:(Data) ->()]] = [:]
	private var cachedWrites: [BTCharacteristicIdentity: (Data, ((BTBroadcasterWriteResponse) ->())?)] = [:]
	private var confirmingWrites: [String: (BTBroadcasterWriteResponse) ->()] = [:]
	private var connected = false {
		didSet {
			if oldValue != connected {
				connectionState = connected ? .connected : .disconnected
			}
		}
	}

	@Published private(set) public var connectionState: ConnectionState = .disconnected

	@Published public var name: String
	
	public init(peripheral : CBPeripheral, advertisementData: [String : Any], service: BTServiceIdentity, makeConnection: @escaping (Bool) ->()) {
		self.id = peripheral.identifier
		self.peripheral = peripheral
		self.service = service
		self.makeConnection = makeConnection
		self.name =
			(advertisementData["kCBAdvDataLocalName"] as? String ??
			 self.peripheral?.name) ??
			 service.name //TODO: add a counter
		super.init()
		peripheral.delegate = self
	}

//TODO: Mock a CBPeripheral instead without testing framework dependency nor having a facade cascade. We may need to bring in some good ol' obj-c dynamics.
	public init(name: String?, deviceID: UUID, service: BTServiceIdentity, makeConnection: @escaping (Bool) ->()) {
		self.id = deviceID
		self.peripheral = nil
		self.service = service
		self.makeConnection = makeConnection
		self.name = name ?? service.name
		super.init()
	}

	public convenience init(preview: String) {
		self.init(
			name: preview,
			deviceID: UUID(),
			service: BTServiceIdentity(name: preview),
			makeConnection: { _ in })
	}

	deinit {
		//self.makeConnection(false)
	}

	public let service: BTServiceIdentity

	public private(set) var id: UUID

	public func connect() {
		if connected == false {
			self.notifyActivating.removeAll()
			self.connectionState = .connecting
			self.makeConnection(true)
		}
	}

	public func disconnect() {
		if connected == true {
			self.notifyActivating.removeAll()
			self.makeConnection(false)
		}
	}
}

extension BTDevice: BTBroadcaster {
	public func send(data: Data, to value: BTCharacteristicIdentity, confirmed: ((BTBroadcasterWriteResponse) ->())?) {
		let identity = service.characteristic(characteristic: value).uuidString
		if let peripheral {
			if let cb = self.characteristics[identity] {
				if let confirmed = confirmed, cb.properties.contains(.write) {
					//TODO: test
					confirmingWrites[identity] = confirmed
					peripheral.writeValue(data, for: cb, type: .withResponse)
				}
				else {
					var completion: ((BTBroadcasterWriteResponse) ->())?
					let old = cachedWrites.removeValue(forKey: value)
					old?.1?(.notSent)
					if peripheral.canSendWriteWithoutResponse {
						completion = confirmed
					}
					else {
						cachedWrites[value] = (data, confirmed)
					}
					//print("Sending: \(data.sbjHexDescription)")
					peripheral.writeValue(data, for: cb, type: .withoutResponse)
					completion?(.sentOnly)
				}
			}
			else {
			// TODO: Mock write
			}
		}
	}
	
	public func read(value: BTCharacteristicIdentity) -> Data? {
		let identity = service.characteristic(characteristic: value).uuidString
		//print("registering: \(identity)")
		if let cb = self.characteristics[identity] {
			return cb.value
		}
		return nil
	}
	
	public func request(value: BTCharacteristicIdentity) {
		let identity = service.characteristic(characteristic: value).uuidString
		if let peripheral, let tx = self.characteristics[identity] {
			peripheral.readValue(for: tx)
		}
	}
	
	public func sink(id: CombineIdentifier, to characteristic: BTCharacteristicIdentity, with: @escaping (Data) -> ()) -> AnyCancellable {
		let identifier = self.service.characteristic(characteristic: characteristic).uuidString
		distribute[id, default: [:]][identifier] = with

		let cb = characteristics[identifier]
		if let cb = cb {
			if cb.properties.contains(.notify) {
				if let peripheral, notifyActivating.contains(identifier) == false {
					notifyActivating.insert(identifier)
					peripheral.setNotifyValue(true, for: cb)
				}
			}
			//TODO: request read?
		}
		return AnyCancellable({self.distribute.removeValue(forKey: id)})
	}
}

extension BTDevice {
	public func peripheralConnected(_ peripheral: CBPeripheral?) {
		if let peripheral {
			peripheral.discoverServices([service.identifer])
		}
		else {
			self.connected = true
		}
	}

	public func peripheralConnectFailed(_ peripheral: CBPeripheral?, _ error: Error?) {
		self.connected = false
	}
	
	public func peripheralDisconnected(_ peripheral: CBPeripheral?, _ error: Error?) {
		//TODO: do these auto error out?
//		confirmingWrites.forEach {
//			$0.value(.error(?))
//		}
		cachedWrites.forEach {
			$0.value.1?(.notSent)
		}
		self.connected = false
	}
}

extension BTDevice: CBPeripheralDelegate {
	public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		for service in peripheral.services ?? [] {
			peripheral.discoverCharacteristics(nil, for: service)
		}
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		for characteristic in service.characteristics ?? [] {
			let identity = characteristic.uuid.uuidString
			self.characteristics[identity] = characteristic
			if let data = characteristic.value, !data.isEmpty {
				self.distribute.forEach {
					if let route = $1[identity] {
						route(data)
					}
				}
			}
			if characteristic.properties.contains(.notify) {
				if notifyActivating.contains(identity) == false {
					let atLeast1Listener = self.distribute.firstIndex { (key, value) in
						value[identity] != nil
					}
					if atLeast1Listener != nil {
						notifyActivating.insert(identity)
						peripheral.setNotifyValue(true, for: characteristic)
					}
				}
			}
			peripheral.discoverDescriptors(for: characteristic)
		}
		self.connected = true
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
//		for descriptor in characteristic.descriptors ?? [] {
//			print("didDiscoverDescriptorsFor \(descriptor.characteristic?.uuid) \(descriptor.value)")
//		}
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
		if (characteristic.isNotifying) {
			if characteristic.value?.isEmpty ?? true {
				if characteristic.properties.contains(.read) {
					peripheral.readValue(for: characteristic)
				}
			}
		}
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		let identifier = characteristic.uuid.uuidString
		if let data = characteristic.value, !data.isEmpty {
			self.distribute.forEach {
				if let route = $1[identifier] {
					route(data)
				}
			}
		}
	}

	//After a failed write...
	public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
		let values = cachedWrites
		cachedWrites.removeAll()
		values.forEach {
			self.send(data: $0.value.0, to: $0.key, confirmed: $0.value.1)
		}
	}

	public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			confirmingWrites.removeValue(forKey: characteristic.uuid.uuidString)?(.error(error))
		}
		else {
			confirmingWrites.removeValue(forKey: characteristic.uuid.uuidString)?(.reponseReceived)
		}
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
		//for service in invalidatedServices {
		//}
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
	}
	
	public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
		if let name = peripheral.name {
			self.name = name
		}
	}
	
	public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
	}
	
	public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
	}
}
