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
import wwdcDld

#if false // development purpose
    //TODO: Any code if you want
    let dateComp = Calendar.current.dateComponents(in: TimeZone.current, from: Date())
    print("This year: \(dateComp.year!)")
    wwdcdl.year = "\(dateComp.year!)"
    print("\(wwdcdl.destinationRootDir())")

    print()
#else

/* Managing options */
let wwdcIndexUrlBaseString = "https://developer.apple.com/videos/"
let wwdcSessionUrlBaseString = "https://developer.apple.com/videos/play/"

///Tracking year of now time
let ThisYear = Calendar.current.dateComponents(in: TimeZone.current, from: Date()).year!
var videoType = String("wwdc\(ThisYear)")
var format = VideoQuality.SD
var videoDownloadMode = VideoDownloadMode.stream

var shouldDownloadPDFResource = false
var shouldDownloadVideoResource = true
var shouldDownloadSampleCodeResource = false

var shouldDownloadTechTalksVideoResource = false
var shouldDownloadWWDCVideoResource = false

var gettingSessions = false
var sessionsSet:Set<String> = Set()

public var destinationDir = getEnv(name: "PWD") ?? ""
wwdcdl.config.destinationDir = getEnv(name: "PWD") ?? ""

var arguments = CommandLine.arguments
arguments.remove(at: 0)

var iterator = arguments.makeIterator()

/// Setup default year
wwdcdl.config.year = "\(ThisYear)"

while let argument = iterator.next() {
    switch argument {

    case "-h", "--help":
        wwdcdl.showHelpAndExit()
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
                wwdcdl.showHelpAndExit()
            }

        } else {
            print("Missing session number")
            wwdcdl.showHelpAndExit()
        }

        break

    case "--list-only", "-l":
        shouldDownloadVideoResource = false
        break

    case "--tech-talks":
        if shouldDownloadWWDCVideoResource == true {
            print("Could not download WWDC and Tech Talks videos at the same time")
            wwdcdl.showHelpAndExit()
        }
        
        videoType = "tech-talks"
        shouldDownloadTechTalksVideoResource = true
        break

    case "--wwdc-year", "--year":
        if shouldDownloadTechTalksVideoResource == true {
            print("Could not download WWDC and Tech Talks videos at the same time")
            wwdcdl.showHelpAndExit()
        }

        if let yearString = iterator.next() {
            if let year = Int(yearString) {
                let today = Date()
                let currentYear = Calendar.current.component(.year, from: today)
                let currentMonth = Calendar.current.component(.month, from: today)

                if year > currentYear || (year == currentYear && currentMonth < 6) {
                    print("WWDC \(yearString) videos are not yet available")
                    wwdcdl.showHelpAndExit()

                } else if year < 2012 {
                    print("WWDC videos earlier than 2012 were not made available for downloads")
                    wwdcdl.showHelpAndExit()

                    
                } else {
                    videoType = "wwdc\(yearString)"
                    wwdcdl.config.year = yearString
                    let destRootDir = wwdcdl.destinationRootDir()
                    if !FileManager.default.fileExists(atPath: destRootDir) {
                        print("Create wwdc directory: \(destRootDir)")
                        try FileManager.default.createDirectory(atPath: destRootDir, withIntermediateDirectories: true, attributes: nil)
                    }
                }

            } else {
                print("\(yearString) is not a valid year")
                wwdcdl.showHelpAndExit()
            }

        } else {
            print("Missing year")
            wwdcdl.showHelpAndExit()
        }

        break
    case "--dir", "-d":// Use $PWD as work dir if not specified
        if let destination = iterator.next() {
            if destination.count > 0, destination[String.Index(utf16Offset: 0, in: destination)] != "-" {
                destinationDir = destination
                wwdcdl.config.destinationDir = destinationDir
            }else {
                wwdcdl.showHelpAndExit(message: "Missing specified path")
            }
        }else {
            wwdcdl.showHelpAndExit(message: "Missing specified path")
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
        wwdcdl.showHelpAndExit()
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
let htmlSessionListString = wwdcdl.getStringContent(fromURL: wwdcIndexUrlString)
print("scrab from: ", wwdcIndexUrlString)
print("session: ", wwdcSessionUrlString)
print("Let me ask Apple about currently available sessions. This can take some times (15 to 20 sec.) ...")
var sessionsListArray = wwdcdl.getSessionsList(fromHTML: htmlSessionListString, type: videoType)
//get unique values
sessionsListArray=Array(Set(sessionsListArray))

/* getting individual videos */
if sessionsSet.count != 0 {
    let sessionsListSet = Set(sessionsListArray)
    sessionsListArray = Array(sessionsSet.intersection(sessionsListSet))
}

sessionsListArray.sorted(by: { $0.compare($1, options: .numeric) == .orderedAscending }).forEach { session in
    let htmlText = wwdcdl.getStringContent(fromURL: wwdcSessionUrlString + session + "/")
    let title = wwdcdl.getTitle(fromHTML: htmlText)
    print("\n[Session \(session)] : \(title), url: \(wwdcSessionUrlString + session + "/")")

    if shouldDownloadVideoResource {
        let url: URL?
        if videoDownloadMode == .stream {
            url = wwdcdl.getM3URLs(fromHTML: htmlText, session: session)
        } else {
            url = wwdcdl.getHDorSDdURLs(fromHTML: htmlText, format: format)
        }

        guard let videoUrl = url else {
            print("Video : Video is not yet available !!!")
            return
        }

        if videoDownloadMode == .stream {
            let filename = makeFilename(fromTitle: title, session: session, format: format.rawValue, ext: "mp4")
            print("Video : \(filename)")
            wwdcdl.downloadStream(playlistUrl: videoUrl, toFile: filename, forFormat: format.rawValue, forSession: session)

        } else {
            print("Video : \(videoUrl.lastPathComponent)")
            wwdcdl.downloadFile(fromUrl: videoUrl, forSession: session)
        }
    }

    if shouldDownloadPDFResource {
        let url = wwdcdl.getPDFResourceURL(fromHTML: htmlText, session: session)
        guard let pdfResourceUrl = url else {
            print("PDF : PDF is not yet available !!!")
            return
        }

        print("PDF : \(pdfResourceUrl.lastPathComponent)")
        wwdcdl.downloadFile(fromUrl: pdfResourceUrl, forSession: session)
    }

    if shouldDownloadSampleCodeResource {
        let sampleUrls = wwdcdl.getSampleCodeURL(fromHTML: htmlText)
        if sampleUrls.isEmpty {
            print("SampleCode: Resource not yet available !!!")
        } else {
            print("SampleCode: ")
            for url in sampleUrls {
                print("\(url.lastPathComponent)")
                wwdcdl.downloadFile(fromUrl: url, forSession: session)
            }
        }
    }
}
#endif
