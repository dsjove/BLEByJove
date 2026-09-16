import Network
import Foundation
import Observation

@MainActor
@Observable
public final class MDNSDevice: DeviceIdentifiable {
    public let service: String
    public nonisolated let id: UUID
    public let endpoint: NWEndpoint

    public var name: String
    public var advertisedData: String = ""

    public init(service: String, endpoint: NWEndpoint, name: String) {
        self.service = service
        id = UUID()
        self.endpoint = endpoint
        self.name = name
    }

    public convenience init(preview: String) {
        self.init(
            service: preview,
            endpoint: .service(name: preview, type: preview, domain: "", interface: nil),
            name: preview
        )
    }
}
