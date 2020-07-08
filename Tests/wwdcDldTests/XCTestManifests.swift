import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(wwdc_downloaderTests.allTests),
    ]
}
#endif
