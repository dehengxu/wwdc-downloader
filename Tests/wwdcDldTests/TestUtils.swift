//
//  File.swift
//  
//
//  Created by NicholasXu on 2020/7/8.
//

import Foundation

func getEnv(name: String!) -> String? {
    var rtn: String?
    name.withCString { (up: UnsafePointer<Int8>) in
        if let env = getenv(up) {
            rtn = String(cString: env)
        }
    }
    return rtn
}

//http://devstreaming.apple.com/videos/wwdc/2013/201xex2xxf5ynwnsgl/201/201.pdf?dl=1
func pdfURL(fromHTML: String, session: String) -> URL? {
    //let pat = "\\b.*(https://.*/\(session)_[^/]*\\.pdf)\\b"
    let pat = "pdf"
    print("pat: \(pat)")
    let regex = try! NSRegularExpression(pattern: pat, options: [])
    let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
    print("matched: \(matches.count)")
    var pdfResourceUrl: URL? = nil
    if !matches.isEmpty {
        let range = matches[0].range(at:1)
        
        let pdfResourceUrlString = String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])
        pdfResourceUrl = URL(string: pdfResourceUrlString)
    }
    return pdfResourceUrl
}
