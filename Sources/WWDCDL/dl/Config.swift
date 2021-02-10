//
//  File.swift
//  
//
//  Created by NicholasXu on 2021/2/7.
//

import Foundation

public struct Config {
    public var destinationDir = getEnv(name: "PWD") ?? ""
    public var year = "2012"
    
    public var format = VideoQuality.SD
    public var videoType = String("wwdc\(ThisYear)")
    public var videoDownloadMode = VideoDownloadMode.stream
    
    public var shouldDownloadPDFResource = false
    public var shouldDownloadVideoResource = true
    public var shouldDownloadSampleCodeResource = false

    public var shouldDownloadTechTalksVideoResource = false
    public var shouldDownloadWWDCVideoResource = false

    public var gettingSessions = false
    public var sessionsSet:Set<String> = Set()

}
