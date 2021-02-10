//
//  File.swift
//  
//
//  Created by NicholasXu on 2021/2/7.
//

import Foundation
import RxSwift

public func getEnv(name: String!) -> String? {
    var rtn: String?
    name.withCString { (up: UnsafePointer<Int8>) in
        if let env = getenv(up) {
            rtn = String(cString: env)
        }
    }
    return rtn
}

public func showHelpAndExit(message: String? = "") {
    if let message = message {
        print(message)
    }
    print("wwdcDownloader - a simple swifty video sessions bulk download.\nJust Get'em all!")
    print("usage: wwdcDownloader.swift [--wwdc-year <year>] [--tech-talks] [--hd1080] [--hd720] [--sd] [--pdf] [--pdf-only] [--sessions <number>] [--sample] [--list-only] [--help]\n")
    exit(0)
}

public func parseArguments(_ args:[String], wwdc: Downloader) {
    var arguments = args
    //arguments.remove(at: 0)
    
    var iterator = arguments.makeIterator()
    var config = wwdc.config
    
    while let argument = iterator.next() {
        switch argument {

        case "-h", "--help":
            showHelpAndExit()
            break

        case "--hd1080":
            config.format = .HD1080
            break

        case "--hd720":
            config.format = .HD720
            config.videoDownloadMode = .file
            break

        case "--sd":
            config.format = .SD
            config.videoDownloadMode = .file
            break

        case "--pdf":
            config.shouldDownloadPDFResource = true
            break

        case "--pdf-only":
            config.shouldDownloadPDFResource = true
            config.shouldDownloadVideoResource = false
            break

        case "--sample":
            config.shouldDownloadSampleCodeResource = true
            break

        case "--sample-only":
            config.shouldDownloadSampleCodeResource = true
            config.shouldDownloadVideoResource = false
            break

        case "--sessions", "-s":
            config.gettingSessions = true

            if let session = iterator.next() {
                if Int(session) != nil {
                    config.sessionsSet.insert(session)

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
            config.shouldDownloadVideoResource = false
            break

        case "--tech-talks":
            if config.shouldDownloadWWDCVideoResource == true {
                print("Could not download WWDC and Tech Talks videos at the same time")
                showHelpAndExit()
            }
            
            config.videoType = "tech-talks"
            config.shouldDownloadTechTalksVideoResource = true
            break

        case "--wwdc-year", "--year":
            if config.shouldDownloadTechTalksVideoResource == true {
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
                        config.videoType = "wwdc\(yearString)"
                        config.year = yearString
                        let destRootDir = wwdc.destinationRootDir()
                        if !FileManager.default.fileExists(atPath: destRootDir) {
                            print("Create wwdc directory: \(destRootDir)")
                            try? FileManager.default.createDirectory(atPath: destRootDir, withIntermediateDirectories: true, attributes: nil)
                        }
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
        case "--dir", "-d":// Use $PWD as work dir if not specified
            if let destination = iterator.next() {
                if destination.count > 0, destination[String.Index(utf16Offset: 0, in: destination)] != "-" {
                    config.destinationDir = destination
                    config.destinationDir = wwdc.config.destinationDir
                }else {
                    showHelpAndExit(message: "Missing specified path")
                }
            }else {
                showHelpAndExit(message: "Missing specified path")
            }
            break
        default:
            if config.gettingSessions {
                if Int(argument) != nil {
                    config.sessionsSet.insert(argument)
                    break
                } else {
                    config.gettingSessions = false
                }
            }
            print("\(argument) is not a \(#file) command.\n")
            showHelpAndExit()
        }
    }
}

public func ffmpeg(command: String, filelist: [String], tsBaseUrl: URL, playlistFileUrl: URL, tempDirBaseUrl: URL, outFile filename: String) {
    let fileManager = FileManager.default
    let tsSize = filelist.reduce(Int64(0)) { initial, file in
        let sum = try! fileManager.attributesOfItem(atPath: file)[FileAttributeKey.size] as! Int64
        return initial + sum
    }
    
    let task = Process()
    task.launchPath = command
    task.arguments = ["-progress", "-", "-i", playlistFileUrl.path, "-c", "copy", filename]
    let standardOutput = Pipe()
    task.standardOutput = standardOutput
    task.standardError = FileHandle.nullDevice
    task.standardInput = FileHandle.nullDevice
    task.launch()
    
    var data = standardOutput.fileHandleForReading.availableData
    
    show(progress: 0, barWidth: 70, speed: String(0), speedUnits: "kbits/s")
    while data.count != 0 {
        let output = String(data: data, encoding: .utf8)!
        
        let bitratePattern = "bitrate=([\\d.]*)kbits"
        let bitrateRegex = try! NSRegularExpression(pattern: bitratePattern, options: [])
        let matchesBitrate = bitrateRegex.matches(in: output, options: [], range: NSRange(location: 0, length: output.count))
        
        let sizePattern = "total_size=(\\d*)\\s"
        let sizeRegex = try! NSRegularExpression(pattern: sizePattern, options: [])
        let matchesSize = sizeRegex.matches(in: output, options: [], range: NSRange(location: 0, length: output.count))
        
        let progressPattern = "\\sprogress=(.*)\\s"
        let progressRegex = try! NSRegularExpression(pattern: progressPattern, options: [])
        let matchesProgress = progressRegex.matches(in: output, options: [], range: NSRange(location: 0, length: output.count))
        
        var speed = "0"
        var progress = 0.0
        var size = 0.0
        
        if !matchesBitrate.isEmpty {
            let bitrateRange = matchesBitrate[0].range(at: 1)
            let bitrate = Double(String(output[output.index(output.startIndex, offsetBy: bitrateRange.location) ..< output.index(output.startIndex, offsetBy: bitrateRange.location + bitrateRange.length)]))!
            
            speed = String(Int((bitrate * 0.125).rounded()))
        }
        
        if !matchesSize.isEmpty {
            let sizeRange = matchesSize[0].range(at: 1)
            size = Double(String(output[output.index(output.startIndex, offsetBy: sizeRange.location) ..< output.index(output.startIndex, offsetBy: sizeRange.location + sizeRange.length)]))!
        }
        
        if !matchesProgress.isEmpty {
            let progressRange = matchesProgress[0].range(at: 1)
            let progressString = String(output[output.index(output.startIndex, offsetBy: progressRange.location) ..< output.index(output.startIndex, offsetBy: progressRange.location + progressRange.length)])
            
            if progressString == "continue" {
                progress = size / Double(tsSize) * 100
            } else {
                progress = 100.0
            }
        }
        
        show(progress: progress, barWidth: 70, speed: speed, speedUnits: "kbits/s")
        
        data = standardOutput.fileHandleForReading.availableData
    }
    
    if !task.isRunning && task.terminationStatus == 0 {
        try? FileManager.default.removeItem(at: tempDirBaseUrl)
    }
    
    print("")
}

public func commandPath(command: String) -> String? {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["command", "-v", command]
    let standardOutput = Pipe()
    task.standardOutput = standardOutput
    task.launch()
    
    var data = standardOutput.fileHandleForReading.readDataToEndOfFile()
    
    if data.count == 0 {
        return nil
        
    } else {
        data.removeLast()
    }
    
    return String(data: data, encoding: .utf8)
}

public func dropProtocol(fromUrlString urlString: String) -> String {
    let pattern = "https*://"
    let regex = try! NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
    let path = regex.stringByReplacingMatches(in: urlString, options: [], range: NSRange(location: 0, length: urlString.count), withTemplate: "")
    
    return path
}

public func makeFilename(fromTitle title: String, session: String, format: String, ext: String) -> String {
    let normalizedTitle = String(title.unicodeScalars.filter { $0.isASCII }
        .map { Character($0) }
        .filter { !"-':,.&".contains($0) }
        .map { $0 == " " ? "_" : $0 }).lowercased()
    
    return session + "_" + format + "p_" + normalizedTitle + "." + ext
}

//MARK: - Rx APIs

private func rxError(_ reason: String = "") -> NSError {
    return NSError(domain: "WWDC RxSwift", code: 0, userInfo: ["reason" : reason])
}

public func rxSession(_ url: String?) -> RxSwift.Observable<String> {
    
    return Observable.create { (s: AnyObserver<String>) -> Disposable in
        var dis: Disposable?
        
        guard let urlstring = url else {
            s.onError(rxError("url is nil"))
            return Disposables.create {
            }
        }

        guard let realURL = URL(string: urlstring) else {
            s.onError(NSError(domain: "wwdc-rx", code: 0, userInfo: ["reason" : "url is nil"]))
            return Disposables.create {
            }
        }
        let req = URLRequest(url: realURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30.0)
        
        let task = URLSession.shared.dataTask(with: req) { (data: Data?, res: URLResponse?, err: Error?) in
            guard let dat = data else {
                if let e = err as NSError? {
                    s.onError(rxError("\(realURL), request failed with error :, \(e.debugDescription)"))
                }else {
                    s.onError(rxError("\(realURL), request failed and no error reason."))
                }
                return;
            }
            guard let result = String(data: dat, encoding: .utf8) else {
                s.onError(rxError("\(realURL), request succeded but data cannot encode to utf8 string"))
                return;
            }
            s.onNext(result)
            s.onCompleted()
        }
        task.resume()
        dis = Disposables.create {
            
        }
        return dis!
    }
}

extension Observable {
    
    func rxSessionList(_ wwdc: Downloader) -> Observable<Array<String>> {
        return RxSwift.Observable.create { (s: AnyObserver<Array<String>>) -> Disposable in
            let d = self.subscribe { (r: Element) in
                let result = wwdc.getSessionsList(fromHTML: r as! String, type: "pdf")
                s.onNext(result)
            } onError: { (e: Error) in
                s.onError(e)
            } onCompleted: {
                s.onCompleted()
            }

            return Disposables.create {
                d.dispose()
            }
        }
    }
    
}
