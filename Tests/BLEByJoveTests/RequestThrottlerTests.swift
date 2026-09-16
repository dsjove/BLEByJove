import XCTest
@testable import BLEByJove

private actor URLRecorder {
    private(set) var urls: [URL] = []
    func append(_ url: URL) { urls.append(url) }
}

final class RequestThrottlerTests: XCTestCase {
    func testRapidRequestsCoalesceToNewestPendingRequest() async throws {
        let recorder = URLRecorder()
        let throttler = RequestThrottler(minimumInterval: .milliseconds(30)) { request in
            await recorder.append(request.url!)
            return Data()
        }

        let one = URL(string: "https://example.invalid/1")!
        let two = URL(string: "https://example.invalid/2")!
        let three = URL(string: "https://example.invalid/3")!

        throttler.sendRequest(url: one)
        throttler.sendRequest(url: two)
        throttler.sendRequest(url: three)

        try await Task.sleep(for: .milliseconds(100))
        let urls = await recorder.urls
        XCTAssertEqual(urls, [one, three])
    }
}
