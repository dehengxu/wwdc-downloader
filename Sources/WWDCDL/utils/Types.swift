//
//  File.swift
//  
//
//  Created by NicholasXu on 2021/2/7.
//

import Foundation

public enum VideoQuality: String {
    case HD1080 = "1080"
    case HD720 = "hd"
    case SD = "sd"
}

public enum VideoDownloadMode {
    case file
    case stream
}

public struct DownloadSlice {
    let source: URL
    let destination: URL
}

