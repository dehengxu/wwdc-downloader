//
//  wwdcdld.swift
//
//  supply wwdc dowload infrastruct
//
//  Created by NicholasXu on 2020/7/8.
//

import Cocoa
import Foundation

//http://stackoverflow.com/a/30743763

public func show(progress: Double, barWidth: Int, speed: String, speedUnits: String) {
    print("\r[", terminator: "")
    let pos = Int(Double(barWidth) * progress / 100.0)
    for i in 0...barWidth {
        switch(i) {
        case _ where i < pos:
            print("🁢", terminator:"")
            break
        case pos:
            print("🁢", terminator:"")
            break
        default:
            print(" ", terminator:"")
            break
        }
    }
    
    print("] \(String(format: "%.2f", progress))% \(speed)\(speedUnits)", terminator:"     \u{8}\u{8}\u{8}\u{8}\u{8}")
    fflush(__stdoutp)
}

/// WWDC downloader
public class Downloader {
    
    public var config = Config()
        
    //MARK: - Initializer
    
    public init() {
        
    }
    
    //MARK: - File system relatived
    
    /// Combine year and destination dir
    public func destinationRootDir() -> String {
        let path: String = getEnv(name: "PWD")!;
        guard config.destinationDir.count != 0 else {
            return "\(path)/wwdc\(config.year)"
        }
        
        return "\(config.destinationDir)/wwdc\(config.year)"
    }
    
    public func destinationFilePath(ofURL: URL) -> String {
        return "\(destinationRootDir())/\(ofURL.lastPathComponent)"
    }
    
    public func destinationFileURL(ofURL url: URL) -> URL {
        return URL(fileURLWithPath: destinationFilePath(ofURL: url))
    }

    public func destinationFileURL(of fileName: String) -> URL {
        return URL(fileURLWithPath: "\(destinationRootDir())/\(fileName)")
    }
    
    //MARK: - Resource utils
    
    public func getWWDCIndexUrl() -> String {
        return wwdcIndexUrlBaseString + config.videoType + "/"
    }
    
    public func getWWDCSessionUrl() -> String {
        return wwdcSessionUrlBaseString + config.videoType + "/"
    }

    public func getSessionsList(fromHTML: String, type: String) -> Array<String> {
        let pat = "\"\\/videos\\/play\\/\(type)\\/([0-9]*)\\/\""
        print("regex pattern: \(pat)")
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
        var sessionsListArray = [String]()
        print("matches: \(matches.count)")
        for match in matches {
            for n in 0..<match.numberOfRanges {
                let range = match.range(at:n)
                let r = Range(range)!
                print("found at: \(n), range begin: \(range.location), length: \(range.length)")
                switch n {
                case 1:
                    let foundStr = String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])

                    var sessionId = 0
                    if Scanner(string: foundStr).scanInt(&sessionId) {
                        print("found sessionID: \(sessionId) from string: \(foundStr)")
                        sessionsListArray.append(foundStr)
                    }else {
                        print("found session error: \(foundStr)")
                    }
                default: break
                }
            }
        }
        return sessionsListArray
    }
    
    public func getM3URLs(fromHTML: String, session: String) -> URL? {
        let pat = "\\b.*(https://.*\\.m3u8)\\b"
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
        var videoUrl: URL? = nil
        if !matches.isEmpty {
            let range = matches[0].range(at: 1)
            let videoUrlString = String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])
            videoUrl = URL(string: videoUrlString)
        }
        
        return videoUrl
    }
    
    public func getPlaylistPath(fromPlaylist playlist: String, format: String) -> String? {
        let patterns = [
            "\\s*#EXT-X-STREAM-INF:.*RESOLUTION=\\d*x" + format + ",.*\\s*(.*)\\s*",
            
            // Fallback to find highest resolution video
            "\\s*#EXT-X-STREAM-INF:.*RESOLUTION=1920x\\d*,.*\\s*(.*)\\s*"
        ]
        
        var path: String?
        for pattern in patterns {
            if let p = matchPlaylistPath(playlist: playlist, format: format, pattern: pattern) {
                path = p
                break
            }
        }
        return path
    }
    
    public func matchPlaylistPath(playlist: String, format: String, pattern: String) -> String? {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: playlist, options: [], range: NSRange(location: 0, length: playlist.count))
        
        var path: String?
        if !matches.isEmpty {
            let range = matches[0].range(at:1)
            path = String(playlist[playlist.index(playlist.startIndex, offsetBy: range.location) ..< playlist.index(playlist.startIndex, offsetBy: range.location + range.length)])
        }
        
        return path
    }
    
    public func getAudioPlaylistPath(fromPlaylist playlist: String) -> String? {
        let pat = "\\s*#EXT-X-MEDIA:TYPE=AUDIO,.*,URI=\"(.*)\""
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: playlist, options: [], range: NSRange(location: 0, length: playlist.count))
        
        if !matches.isEmpty {
            let range = matches[0].range(at:1)
            let path = String(playlist[playlist.index(playlist.startIndex, offsetBy: range.location) ..< playlist.index(playlist.startIndex, offsetBy: range.location + range.length)])
            
            return path
        }
        
        return nil
    }
    
    public func getSliceURLs(fromPlaylist playlist: String, baseURL: URL) -> [URL] {
        let pat = "#.*,\\s*(.*)\\s*"
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: playlist, options: [], range: NSRange(location: 0, length: playlist.count))
        
        return matches.map { $0.range(at: 1) }
            .map { String(playlist[playlist.index(playlist.startIndex, offsetBy: $0.location) ..< playlist.index(playlist.startIndex, offsetBy: $0.location + $0.length)]) }
            .sorted()
            .map { baseURL.appendingPathComponent($0) }
    }
    
    public func getHDorSDdURLs(fromHTML: String, format: VideoQuality) -> URL? {
        let pat = "\\b.*(https://.*" + format.rawValue + ".*\\.mp4)\\b"
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
        var videoUrl: URL? = nil
        if !matches.isEmpty {
            let range = matches[0].range(at: 1)
            let videoUrlString = String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])
            videoUrl = URL(string: videoUrlString)
        }
        
        return videoUrl
    }
    
    public func getPDFResourceURL(fromHTML: String, session: String) -> URL? {
        //let pat = "\\b.*(https://.*/\(session)_[^/]*\\.pdf)\\b"
        let pat = "\\\"http.*\\.pdf.*\\\""
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
        var pdfResourceUrl: URL? = nil
        if !matches.isEmpty {
			if let range = matches.last?.range(at:0) {
				let r = (String.Index(utf16Offset: range.location+1, in: fromHTML)...String.Index(utf16Offset: range.location+range.length-2, in: fromHTML))
				let pdfResourceUrlString =
					fromHTML[r]
					//String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])
				pdfResourceUrl = URL(string: String(pdfResourceUrlString))
			}
        }
        return pdfResourceUrl
    }
    
    public func getTitle(fromHTML: String) -> (String) {
        let pat = "<h1>(.*)</h1>"
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
        var title = ""
        if !matches.isEmpty {
            let range = matches[0].range(at:1)
            title = String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])
        }
        
        return title
    }
    
    public func getSampleCodeURL(fromHTML: String) -> [URL] {
        let pat = "\\b.*(class=\"download\"\\>\\<a href=\".*\")\\b"
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        let matches = regex.matches(in: fromHTML, options: [], range: NSRange(location: 0, length: fromHTML.count))
        var sampleURLPaths : [String] = []
        for match in matches {
            let range = match.range(at:1)
            var path = String(fromHTML[fromHTML.index(fromHTML.startIndex, offsetBy: range.location) ..< fromHTML.index(fromHTML.startIndex, offsetBy: range.location+range.length)])
            path = path.replacingOccurrences(of: "class=\"download\"><a href=\"", with: "")
            if (!path.contains("https://developer.apple.com")) {
                path = "https://developer.apple.com" + path
            }
            path = path.replacingOccurrences(of: "\" target=\"", with: "/")
            
            sampleURLPaths.append(path)
        }
        
        var sampleArchiveUrls : [URL] = []
        for urlPath in sampleURLPaths {
            if let url = getDownloadPageURL(urlPath: urlPath) {
                sampleArchiveUrls.append(url)
            }
        }
        
        return sampleArchiveUrls
    }
    
    public func getDownloadPageURL(urlPath: String) -> URL? {
        let archivePat = "href=\"https.*?\\.zip"
        let archiveRegex = try! NSRegularExpression(pattern: archivePat, options: [])
        let downloadPage = getStringContent(fromURL: urlPath)
        let matches = archiveRegex.matches(in: downloadPage, options: [], range: NSRange(location: 0, length: downloadPage.count))
        for match in matches {
            let range = match.range(at:0)
            var path = String(downloadPage[downloadPage.index(downloadPage.startIndex, offsetBy: range.location) ..< downloadPage.index(downloadPage.startIndex, offsetBy: range.location+range.length)])
            path = path.replacingOccurrences(of: "href=\"", with: "")
            return URL(string: path)
        }
        
        return nil
    }
    
    public func getStringContent(fromURL: String) -> (String) {
        /* Configure session, choose between:
         * defaultSessionConfiguration
         * ephemeralSessionConfiguration
         * backgroundSessionConfigurationWithIdentifier:
         And set session-wide properties, such as: HTTPAdditionalHeaders,
         HTTPCookieAcceptPolicy, requestCachePolicy or timeoutIntervalForRequest.
         */
        
        /* Create session, and optionally set a URLSessionDelegate. */
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
        
        /* Create the Request:
         My API (2) (GET https://developer.apple.com/videos/play/wwdc2019/201/)
         https://developer.apple.com/videos/play/wwdc2019/102/
         */
        var result = ""
        guard let URL = URL(string: fromURL) else {return result}
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        
        /* Start a new Task */
        let semaphore = DispatchSemaphore.init(value: 0)
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if (error == nil) {
                /* Success */
                // let statusCode = (response as! NSHTTPURLResponse).statusCode
                // print("URL Session Task Succeeded: HTTP \(statusCode)")
                result = String.init(data: data!, encoding:
                    .ascii)!
            }
            else {
                /* Failure */
                print("URL Session Task Failed: %@", error!.localizedDescription);
            }
            
            semaphore.signal()
        })
        task.resume()
        semaphore.wait()
        return result
    }
    
    public func downloadFile(fromUrl url: URL, forSession session: String = "???") {
		var fileUrl: URL
        if config.year == "2012" {
			let comps = url.query?.components(separatedBy: "=")
			fileUrl = destinationFileURL(of: (comps?.last)!)
			fileUrl = destinationFileURL(of: fileUrl.lastPathComponent)
		} else {
			fileUrl = destinationFileURL(ofURL: url)
		}

        guard !FileManager.default.fileExists(atPath: destinationFilePath(ofURL: fileUrl)) else {
            print("\(url.lastPathComponent): already exists, nothing to do!")
            return
        }
        
        print("[Session \(session)] Getting \(fileUrl.lastPathComponent) from: \(url.absoluteString)")
        print("destinationDir: \(destinationFilePath(ofURL: fileUrl))")
        DownloadSessionManager.shared.downloadFile(fromURL: url, toFileURL: fileUrl.deletingLastPathComponent())
    }
    
    public func downloadStream(playlistUrl: URL, toFile filename: String, forFormat format: String = "1080", forSession session: String = "???") {
        
        let fileManager = FileManager.default
        
        let fileUrl = destinationFileURL(of: filename)//URL(fileURLWithPath: filename)
        
        guard !fileManager.fileExists(atPath: "./" + filename) else {
            print("\(filename): already exists, nothing to do!")
            return
        }
        
        print("[Session \(session)] Getting \(filename):")
        
        guard let playlist = try? String(contentsOf: playlistUrl) else {
            print("\(filename): could not download playlist!")
            return
        }
        
        guard let playlistPath = getPlaylistPath(fromPlaylist: playlist, format: format) else {
            print("Something went wrong getting download path")
            return
        }
        
        let slicesURL: URL?
        let sliceRelativePath: String
        if playlistPath.hasPrefix("https://") {
            slicesURL = URL(string: playlistPath)
            sliceRelativePath = String(playlistPath.dropFirst(8))
            
        } else if playlistPath.hasPrefix("http://") {
            slicesURL = URL(string: playlistPath)
            sliceRelativePath = String(playlistPath.dropFirst(7))
            
        } else {
            slicesURL = playlistUrl.deletingLastPathComponent().appendingPathComponent(playlistPath)
            sliceRelativePath = playlistPath
        }
        
        guard let slicePlaylistURL = slicesURL, let slicePlaylist = try? String(contentsOf: slicePlaylistURL) else {
            print("\(filename): Could not retrieve stream playlist!")
            return
        }
        
        let baseURL = slicePlaylistURL.deletingLastPathComponent()
        let sliceURLs = getSliceURLs(fromPlaylist: slicePlaylist, baseURL: baseURL)
        
        let tempUrl = fileUrl.appendingPathExtension("part")
        
        guard let newPlaylist = cleanupPlaylist(playlist: playlist, format: format),
            let videoUrl = getVideoUrl(playlist: newPlaylist, baseUrl:  tempUrl) else {
                print("Something went wrong getting video path")
                
                return
        }
        
        try? fileManager.createDirectory(at: videoUrl, withIntermediateDirectories: true, attributes: nil)
        // TODO: Check if directory already exist and handle error
        
        let playlistFileUrl = tempUrl.appendingPathComponent("playlist").appendingPathExtension("m3u8")
        let slicePlaylistFileUrl = tempUrl.appendingPathComponent(sliceRelativePath)
        try? fileManager.removeItem(at: playlistFileUrl)
        try? fileManager.removeItem(at: slicePlaylistFileUrl)
        do {
            try newPlaylist.write(to: playlistFileUrl, atomically: false, encoding: .utf8)
            try slicePlaylist.write(to: slicePlaylistFileUrl, atomically: false, encoding: .utf8)
            
        } catch {
            print("Could not write playlist file!")
            try? fileManager.removeItem(at: tempUrl)
            
            return
        }
        
        var downloadSlices = sliceURLs.map { DownloadSlice(source: $0, destination: videoUrl) }
        
        if let audioPlaylistPath = getAudioPlaylistPath(fromPlaylist: newPlaylist),
            let audioUrl = getAudioUrl(playlist: newPlaylist, baseUrl: tempUrl) {
            
            let audioSlicesUrl = playlistUrl.deletingLastPathComponent().appendingPathComponent(audioPlaylistPath)
            let audioBaseUrl = audioSlicesUrl.deletingLastPathComponent()
            guard let audioSlicePlaylist = try? String(contentsOf: audioSlicesUrl) else {
                print("\(filename): Could not retrieve audio stream playlist!")
                return
            }
            
            let audioSliceURLs = getSliceURLs(fromPlaylist: audioSlicePlaylist, baseURL: audioBaseUrl)
            
            let sliceAudioPlaylistFileUrl = tempUrl.appendingPathComponent(audioPlaylistPath)
            
            try? fileManager.createDirectory(at: audioUrl, withIntermediateDirectories: true, attributes: nil)
            try? fileManager.removeItem(at: sliceAudioPlaylistFileUrl)
            do {
                try audioSlicePlaylist.write(to: sliceAudioPlaylistFileUrl, atomically: false, encoding: .utf8)
                
            } catch {
                print("Could not write playlist file!")
                
                return
            }
            
            downloadSlices += audioSliceURLs.map { DownloadSlice(source: $0, destination: audioUrl) }
        }
        
        DownloadSessionManager.shared.downloadStream(slices: downloadSlices)
        
        if let command = commandPath(command: "ffmpeg") {
            print("[Session \(session)] Converting (ffmpeg) \(filename):")
            
            let ffmpegFilelist = sliceURLs.map { videoUrl.appendingPathComponent($0.lastPathComponent).path }
            ffmpeg(command: command, filelist: ffmpegFilelist, tsBaseUrl: playlistUrl, playlistFileUrl: playlistFileUrl, tempDirBaseUrl: tempUrl, outFile: filename)
            
        } else {
            print("No converter!")
        }
    }
    
    public func getVideoUrl(playlist: String, baseUrl: URL) -> URL? {
        let regex = try! NSRegularExpression(pattern: "^#EXT-X-STREAM-INF:.*\n*(.*)/", options: [.anchorsMatchLines])
        let matches = regex.matches(in: playlist, options: [], range: NSRange(location: 0, length: playlist.count))
        
        if !matches.isEmpty {
            let range = matches[0].range(at: 1)
            let path = String(playlist[playlist.index(playlist.startIndex, offsetBy: range.location) ..<
                playlist.index(playlist.startIndex, offsetBy: range.location+range.length)])
            
            let videoPath = dropProtocol(fromUrlString: path)
            
            return baseUrl.appendingPathComponent(videoPath)
        }
        
        return nil
    }
    
    public func getAudioUrl(playlist: String, baseUrl: URL) -> URL? {
        let audioPathRegex = try! NSRegularExpression(pattern: "^#EXT-X-MEDIA:TYPE=AUDIO,.*,URI=\"(.*)/.*\"", options: [.anchorsMatchLines])
        let audioPathMatches = audioPathRegex.matches(in: playlist, options: [], range: NSRange(location: 0, length: playlist.count))
        var audioPath = ""
        if !audioPathMatches.isEmpty {
            let range = audioPathMatches[0].range(at: 1)
            audioPath = String(playlist[playlist.index(playlist.startIndex, offsetBy: range.location) ..<
                playlist.index(playlist.startIndex, offsetBy: range.location+range.length)])
            
            return baseUrl.appendingPathComponent(audioPath)
        }
        
        return nil
    }
    
    public func cleanupPlaylist(playlist: String, format: String) -> String? {
        let patterns = [
            "\n#EXT-X-STREAM-INF:.*RESOLUTION=\\d*x" + format + ",.*\n*.*\n#EXT-X-I-FRAME-STREAM-INF:[^\n]*",
            "\n#EXT-X-STREAM-INF:.*RESOLUTION=\\d*x" + format + ",[^\n]*\n[^\n]*\n",
            
            // Fallback to find highest resolution video
            "\n#EXT-X-STREAM-INF:.*RESOLUTION=1920x\\d*,.*\n.*\n#EXT-X-I-FRAME-STREAM-INF:[^\n]*",
            "\n#EXT-X-STREAM-INF:.*RESOLUTION=1920x\\d*,[^\n]*\n[^\n]*\n"
        ]
        
        var newPlaylist: String?
        
        for pattern in patterns {
            if let pl = keepOnly(playlist: playlist, withPattern: pattern) {
                newPlaylist = pl
                break
            }
        }
        
        return newPlaylist
    }
    
    public func keepOnly(playlist: String, withPattern pattern: String) -> String? {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: playlist, options: [.withTransparentBounds], range: NSRange(location: 0, length: playlist.count))
        
        var videoStreamLine: String?
        if !matches.isEmpty {
            let range = matches[0].range
            
            let streamLine = String(playlist[playlist.index(playlist.startIndex, offsetBy: range.location) ..<
                playlist.index(playlist.startIndex, offsetBy: range.location + range.length)])
            
            videoStreamLine = dropProtocol(fromUrlString: streamLine)
        }
        
        if let videoStreamLine = videoStreamLine {
            let pattern = "#EXT-X-STREAM-INF:.*[^\n]*"
            let regex = try! NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            let newPlaylist = regex.stringByReplacingMatches(in: playlist, options: [], range: NSRange(location: 0, length: playlist.count), withTemplate: videoStreamLine)
            
            return newPlaylist
        }
        
        return nil
    }
    
}
