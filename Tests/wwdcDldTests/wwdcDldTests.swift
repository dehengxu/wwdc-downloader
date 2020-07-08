import XCTest
@testable import wwdc_downloader

final class wwdc_downloaderTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(wwdc_downloader().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
