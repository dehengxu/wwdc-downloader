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
 
	TODO:
 - basically all previous script option (previuous years, checks, cleaner code, etc.)
 
 
 Note: SF Tested with Apple Swift version 4.2.1 (swiftlang-1000.11.42 clang-1000.11.45.1)
 */

import Cocoa
import Foundation
import SystemConfiguration
import wwdcDld

func getEnv(name: String!) -> String? {
    var rtn: String?
    name.withCString { (up: UnsafePointer<Int8>) in
        if let env = getenv(up) {
            rtn = String(cString: env)
        }
    }
    return rtn
}

#if false
let path = getEnv(name: "HOME")!
let content = try String(contentsOfFile: "\(path)/Projects/3rd/wwdc-downloader/Tests/wwdcDldTests/data/wwdc2013.html")
//let content = "boo.pdf"
//http://devstreaming.apple.com/videos/wwdc/2013/201xex2xxf5ynwnsgl/201/201.pdf?dl=1
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

#else

/* Managing options */
let wwdcIndexUrlBaseString = "https://developer.apple.com/videos/"
let wwdcSessionUrlBaseString = "https://developer.apple.com/videos/play/"
var videoType = "wwdc2020"
var format = VideoQuality.SD
var videoDownloadMode = VideoDownloadMode.stream

var shouldDownloadPDFResource = true
var shouldDownloadVideoResource = false
var shouldDownloadSampleCodeResource = false

var shouldDownloadTechTalksVideoResource = false
var shouldDownloadWWDCVideoResource = false

var gettingSessions = false
var sessionsSet:Set<String> = Set()

var arguments = CommandLine.arguments
arguments.remove(at: 0)

var iterator = arguments.makeIterator()

while let argument = iterator.next() {
    switch argument {

    case "-h", "--help":
        showHelpAndExit()
        break

    case "--hd1080":
        format = .HD1080
        break

    case "--hd720":
        format = .HD720
        videoDownloadMode = .file
        break

    case "--sd":
        format = .SD
        videoDownloadMode = .file
        break

    case "--pdf":
        shouldDownloadPDFResource = true
        break

    case "--pdf-only":
        shouldDownloadPDFResource = true
        shouldDownloadVideoResource = false
        break

    case "--sample":
        shouldDownloadSampleCodeResource = true
        break

    case "--sample-only":
        shouldDownloadSampleCodeResource = true
        shouldDownloadVideoResource = false
        break

    case "--sessions", "-s":
        gettingSessions = true

        if let session = iterator.next() {
            if Int(session) != nil {
                sessionsSet.insert(session)

            } else {
                print("\(session) is not a valid session nuber")
                showHelpAndExit()
            }

        } else {
            print("Missing session number")
            showHelpAndExit()
        }

        break

    case "--list-only", "-l":
        shouldDownloadPDFResource = false
        break

    case "--tech-talks":
        if shouldDownloadWWDCVideoResource == true {
            print("Could not download WWDC and Tech Talks videos at the same time")
            showHelpAndExit()
        }
        
        videoType = "tech-talks"
        shouldDownloadTechTalksVideoResource = true
        break

    case "--wwdc-year":
        if shouldDownloadTechTalksVideoResource == true {
            print("Could not download WWDC and Tech Talks videos at the same time")
            showHelpAndExit()
        }

        if let yearString = iterator.next() {
            if let year = Int(yearString) {
                let today = Date()
                let currentYear = Calendar.current.component(.year, from: today)
                let currentMonth = Calendar.current.component(.month, from: today)

                if year > currentYear || (year == currentYear && currentMonth < 6) {
                    print("WWDC \(yearString) videos are not yet available")
                    showHelpAndExit()

                } else if year < 2012 {
                    print("WWDC videos earlier than 2012 were not made available for downloads")
                    showHelpAndExit()

                    
                } else {
                    videoType = "wwdc\(yearString)"
                    shouldDownloadWWDCVideoResource = true
                }

            } else {
                print("\(yearString) is not a valid year")
                showHelpAndExit()
            }

        } else {
            print("Missing year")
            showHelpAndExit()
        }

        break

    default:
	if gettingSessions {
            if Int(argument) != nil {
                sessionsSet.insert(argument)
                break
            } else {
                gettingSessions = false
            }
        }
        print("\(argument) is not a \(#file) command.\n")
        showHelpAndExit()
    }
}

var wwdcIndexUrlString = wwdcIndexUrlBaseString + videoType + "/"
var wwdcSessionUrlString = wwdcSessionUrlBaseString + videoType + "/"

if(shouldDownloadVideoResource) {
    switch format {
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
let htmlSessionListString = wwdcVideosController.getStringContent(fromURL: wwdcIndexUrlString)
print("scrab from: ", wwdcIndexUrlString)
print("session: ", wwdcSessionUrlString)
print("Let me ask Apple about currently available sessions. This can take some times (15 to 20 sec.) ...")
var sessionsListArray = wwdcVideosController.getSessionsList(fromHTML: htmlSessionListString, type: videoType)
//get unique values
sessionsListArray=Array(Set(sessionsListArray))

/* getting individual videos */
if sessionsSet.count != 0 {
    let sessionsListSet = Set(sessionsListArray)
    sessionsListArray = Array(sessionsSet.intersection(sessionsListSet))
}

sessionsListArray.sorted(by: { $0.compare($1, options: .numeric) == .orderedAscending }).forEach { session in
    let htmlText = wwdcVideosController.getStringContent(fromURL: wwdcSessionUrlString + session + "/")
    let title = wwdcVideosController.getTitle(fromHTML: htmlText)
    print("\n[Session \(session)] : \(title), url: \(wwdcSessionUrlString + session + "/")")

    if shouldDownloadVideoResource {
        let url: URL?
        if videoDownloadMode == .stream {
            url = wwdcVideosController.getM3URLs(fromHTML: htmlText, session: session)
        } else {
            url = wwdcVideosController.getHDorSDdURLs(fromHTML: htmlText, format: format)
        }

        guard let videoUrl = url else {
            print("Video : Video is not yet available !!!")
            return
        }

        if videoDownloadMode == .stream {
            let filename = makeFilename(fromTitle: title, session: session, format: format.rawValue, ext: "mp4")
            print("Video : \(filename)")
            wwdcVideosController.downloadStream(playlistUrl: videoUrl, toFile: filename, forFormat: format.rawValue, forSession: session)

        } else {
            print("Video : \(videoUrl.lastPathComponent)")
            wwdcVideosController.downloadFile(fromUrl: videoUrl, forSession: session)
        }
    }

    if shouldDownloadPDFResource {
        let url = wwdcVideosController.getPDFResourceURL(fromHTML: htmlText, session: session)
        guard let pdfResourceUrl = url else {
            print("PDF : PDF is not yet available !!!")
            return
        }

        print("PDF : \(pdfResourceUrl.lastPathComponent)")
        wwdcVideosController.downloadFile(fromUrl: pdfResourceUrl, forSession: session)
    }

    if shouldDownloadSampleCodeResource {
        let sampleUrls = wwdcVideosController.getSampleCodeURL(fromHTML: htmlText)
        if sampleUrls.isEmpty {
            print("SampleCode: Resource not yet available !!!")
        } else {
            print("SampleCode: ")
            for url in sampleUrls {
                print("\(url.lastPathComponent)")
                wwdcVideosController.downloadFile(fromUrl: url, forSession: session)
            }
        }
    }
}
#endif
