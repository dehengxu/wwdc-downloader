/*
	Author: Olivier HO-A-CHUCK
	Date: June 17th 2017
	About this script:
 WWDC 2019 is ending and even if there are some great tools out there (https://github.com/insidegui/WWDC) that allow to see and download video sessions,
 I Still need to get my video doggy bag to fly back home. And Moscone alsways provide with great bandwidth.
 So as I had never really started to code in Swift I decided to start here (I know it's late - but I'm no more a developer) and copy/pasted some internet peace
 of codes to get a Swift Script that bulk download all sessions.
 You may have understand my usual disclamer : "I'm a Marketing guy" so don't blame my messy (Swift beginer) code.
 Please feel free to make this script better if you feel like so. There is plenty to do.
	
	License: Do what you want with it. But notice that this script comes with no warranty and will not be maintained.
	Usage: wwdcDownloader.swift
	Default behavior: without any options the script will download all available hd1080 videos. And will re-take non fully downloaded ones.
	Please use --help option to get currently available options
 
	TODO
 - basically all previous script option (previuous years, checks, cleaner code, etc.)
 
 
 Note: SF Tested with Apple Swift version 4.2.1 (swiftlang-1000.11.42 clang-1000.11.45.1)
 */

import Cocoa
import Foundation
import SystemConfiguration
import WWDCDL

#if true // development purpose
    //TODO: Any code if you want
    let dateComp = Calendar.current.dateComponents(in: TimeZone.current, from: Date())
    let wwdc = Downloader()
    print("This year: \(dateComp.year!)")
    wwdc.config.year = "\(dateComp.year!)"
    print("\(wwdc.destinationRootDir())")

    print()
#else

let wwdc = Downloader()
wwdc.config.destinationDir = getEnv(name: "PWD") ?? ""

var arguments = CommandLine.arguments
arguments.remove(at: 0)

var iterator = arguments.makeIterator()

/// Setup default year
wwdc.config.year = "\(ThisYear)"

parseArguments(arguments, wwdc: wwdc)

var wwdcIndexUrlString = wwdc.getWWDCIndexUrl()
var wwdcSessionUrlString = wwdc.getWWDCSessionUrl()

if(wwdc.shouldDownloadVideoResource) {
    switch wwdc.format {
    case .HD1080:
        if commandPath(command: "ffmpeg") == nil {
            print("Could not find ffmpeg. wwdcDownloader will download video stream but will not be able to convert to mp4 video files.")
            print("Convertion can be done after the stream files are downloaded and ffmpeg installed.")

        } else {
            print("Downloading 1080p videos in current directory")
        }

    case .HD720:
        print("Downloading 720p videos in current directory")

    case .SD:
        print("Downloading SD videos in current directory")
    }
}

/* Retreiving list of all video session */
let htmlSessionListString = wwdc.getStringContent(fromURL: wwdcIndexUrlString)
print("scrab from: ", wwdcIndexUrlString)
print("session: ", wwdcSessionUrlString)
print("Let me ask Apple about currently available sessions. This can take some times (15 to 20 sec.) ...")
var sessionsListArray = wwdc.getSessionsList(fromHTML: htmlSessionListString, type: wwdc.videoType)
//get unique values
sessionsListArray=Array(Set(sessionsListArray))

/* getting individual videos */
if wwdc.sessionsSet.count != 0 {
    let sessionsListSet = Set(sessionsListArray)
    sessionsListArray = Array(wwdc.sessionsSet.intersection(sessionsListSet))
}

sessionsListArray.sorted(by: { $0.compare($1, options: .numeric) == .orderedAscending }).forEach { session in
    let htmlText = wwdc.getStringContent(fromURL: wwdcSessionUrlString + session + "/")
    let title = wwdc.getTitle(fromHTML: htmlText)
    print("\n[Session \(session)] : \(title), url: \(wwdcSessionUrlString + session + "/")")

    if wwdc.shouldDownloadVideoResource {
        let url: URL?
        if wwdc.videoDownloadMode == .stream {
            url = wwdc.getM3URLs(fromHTML: htmlText, session: session)
        } else {
            url = wwdc.getHDorSDdURLs(fromHTML: htmlText, format: wwdc.format)
        }

        guard let videoUrl = url else {
            print("Video : Video is not yet available !!!")
            return
        }

        if wwdc.videoDownloadMode == .stream {
            let filename = makeFilename(fromTitle: title, session: session, format: wwdc.format.rawValue, ext: "mp4")
            print("Video : \(filename)")
            wwdc.downloadStream(playlistUrl: videoUrl, toFile: filename, forFormat: wwdc.format.rawValue, forSession: session)

        } else {
            print("Video : \(videoUrl.lastPathComponent)")
            wwdc.downloadFile(fromUrl: videoUrl, forSession: session)
        }
    }

    if wwdc.shouldDownloadPDFResource {
        let url = wwdc.getPDFResourceURL(fromHTML: htmlText, session: session)
        guard let pdfResourceUrl = url else {
            print("PDF : PDF is not yet available !!!")
            return
        }

        print("PDF : \(pdfResourceUrl.lastPathComponent)")
        wwdc.downloadFile(fromUrl: pdfResourceUrl, forSession: session)
    }

    if wwdc.shouldDownloadSampleCodeResource {
        let sampleUrls = wwdc.getSampleCodeURL(fromHTML: htmlText)
        if sampleUrls.isEmpty {
            print("SampleCode: Resource not yet available !!!")
        } else {
            print("SampleCode: ")
            for url in sampleUrls {
                print("\(url.lastPathComponent)")
                wwdc.downloadFile(fromUrl: url, forSession: session)
            }
        }
    }
}
#endif
