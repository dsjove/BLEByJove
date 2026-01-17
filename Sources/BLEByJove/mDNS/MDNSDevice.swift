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
