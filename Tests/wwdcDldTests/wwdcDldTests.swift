import XCTest
import Foundation

@testable import wwdcDld

final class wwdcDldTests: XCTestCase {
    
    func test_PDFResourceURL() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        //XCTAssertEqual(wwdc_downloader().text, "Hello, World!")
        
        //wwdc 2013 - session 201 - pdf url: http://devstreaming.apple.com/videos/wwdc/2013/201xex2xxf5ynwnsgl/201/201.pdf?dl=1
        
        let path = getEnv(name: "HOME")!
        let content = try! String(contentsOfFile: "\(path)/\(getEnv(name: "HTML_PATH")!)")
        let pattern = "\\\"http.*\\.pdf.*\\\""
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.count))
        print("matches count: \(matches.count)")
        if !matches.isEmpty, let result: NSTextCheckingResult = matches.last {
            //let range = matches[0].range(at:1)
            print("type: \(result.resultType)")
            let range = result.range(at: 0)
            print("num: \(result.numberOfRanges), range: \(range.location) - \(range.length)")
            
            let r = (String.Index(utf16Offset: range.location+1, in: content)...String.Index(utf16Offset: range.location+range.length-2, in: content))
            print("\(content[r])")
            //print("\(content[Range(range, in: content)!])")
        }
    }

    static var allTests = [
        ("test_PDFResourceURL", test_PDFResourceURL),
    ]
}
