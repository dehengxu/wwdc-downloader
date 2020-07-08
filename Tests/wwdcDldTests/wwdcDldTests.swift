import XCTest
import Foundation

@testable import wwdcDld

final class wwdc_downloaderTests: XCTestCase {
    
    func test_PDFResourceURL() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        //XCTAssertEqual(wwdc_downloader().text, "Hello, World!")
        
        //wwdc 2013 - session 201 - pdf url: http://devstreaming.apple.com/videos/wwdc/2013/201xex2xxf5ynwnsgl/201/201.pdf?dl=1
        do {
            guard let path = getEnv(name: "HOME") else {
                return
            }
            let htmlStr = try String(contentsOfFile: "\(path)/Projects/3rd/wwdc-downloader/Tests/wwdcDldTests/data/wwdc2013.html")
            assert(htmlStr.count > 0, "htmlStr is empty.")
            let pdfUrl = pdfURL(fromHTML: htmlStr, session: "201")
            print("pdfUrl: \(String(describing: pdfUrl))")
        }catch {
            print(error)
        }
    }

    static var allTests = [
        ("test_PDFResourceURL", test_PDFResourceURL),
    ]
}
