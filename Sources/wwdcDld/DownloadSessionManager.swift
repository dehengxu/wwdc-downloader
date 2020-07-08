//
//  DownloadSessionManager.swift
//  
//
//  Created by Deheng Xu on 2020/7/8.
//

import Foundation

class DownloadSessionManager : NSObject, URLSessionDownloadDelegate {

    static let shared = DownloadSessionManager()
    var fileUrl : URL?
    var url: URL?
    var resumeData: Data?

    var taskStartedAt : Date?
    var downloadedCount = 0
    var totalFileCount = 0
    var cumulativeBytesWritten = Int64(0)

    let semaphore = DispatchSemaphore.init(value: 0)
    var session : URLSession!

    var mode: VideoDownloadMode!

    func resetSession() {
		if self.session != nil {
			return;
		}
		self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }

    func downloadFile(fromURL url: URL, toFileURL path: URL) {
        self.mode = .file
        resetSession()
        self.fileUrl = path
        self.url = url
        self.resumeData = nil
        taskStartedAt = Date()
        let task = session.downloadTask(with: url)
        task.resume()
        semaphore.wait()
        print("")
    }

    func downloadStream(slices: [DownloadSlice]) {
        self.mode = .stream
        downloadedCount = 0
        totalFileCount = slices.count
        cumulativeBytesWritten = 0

        taskStartedAt = Date()

        show(progress: 0, barWidth: 70, speed: String(0), speedUnits: "KB/s")
        slices.forEach { slice in
            let destination = slice.destination.appendingPathComponent(slice.source.lastPathComponent).path
            guard !FileManager.default.fileExists(atPath: destination) else {
                downloadedCount += 1

                return
            }

            resetSession()
            self.fileUrl = slice.destination
            self.url = slice.source
            self.resumeData = nil
            let task = session.downloadTask(with: slice.source)
            task.resume()
            semaphore.wait()
        }

        let now = Date()
        let timeDownloaded = now.timeIntervalSince(taskStartedAt!)
        let kbs = String(Int(floor( Float(cumulativeBytesWritten) / 1024.0 / Float(timeDownloaded) ) ))
        show(progress: Double(downloadedCount)/Double(totalFileCount)*100.0, barWidth: 70, speed: kbs, speedUnits: "KB/s")
        print("")
    }

    func resumeDownload() {
        //TODO: reset session in appropriate URLSessionDelegate function?
        self.resetSession()

        if let resumeData = self.resumeData {
			print("resuming file download...\(self.url!)")
            let task = session.downloadTask(withResumeData: resumeData)
            task.resume()
            self.resumeData = nil
            semaphore.wait()
        } else {
            print("retrying file download...\(self.url!)")
            self.downloadFile(fromURL: self.url!, toFileURL: self.fileUrl!)
        }
    }

    //MARK : URLSessionDownloadDelegate stuff
    func urlSession(_: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {

        let now = Date()
        let timeDownloaded = now.timeIntervalSince(taskStartedAt!)
        if mode == .stream {
            self.cumulativeBytesWritten += bytesWritten
            let kbs = String(Int(floor( Float(cumulativeBytesWritten) / 1024.0 / Float(timeDownloaded) ) ))
            show(progress: Double(downloadedCount)/Double(totalFileCount)*100.0, barWidth: 70, speed: kbs, speedUnits: "KB/s")

        } else if mode == .file {
            let kbs = String(Int( floor( Float(totalBytesWritten) / 1024.0 / Float(timeDownloaded) ) ))
            show(progress: Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)*100.0, barWidth: 70, speed: kbs, speedUnits: "KB/s")
        }
    }

    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        defer {
            semaphore.signal()
        }

        guard let destination = fileUrl?.appendingPathComponent(url!.lastPathComponent) else {
            return
        }

        do {
            try FileManager.default.moveItem(at: location, to: destination)
			print("\nSaved file to: \(destination.absoluteString)")
        } catch let error {
            print("\nOoops! Something went wrong: \(error)")
        }

        downloadedCount += 1
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else {
            //No error. Already handled in URLSession(session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingToURL location: URL)
            return
        }

        defer {
            defer {
                semaphore.signal()
            }

            if !Reachability.isConnectedToNetwork() {
                print("Waiting for connection to be restored")
                repeat {
                    sleep(1)
                } while !Reachability.isConnectedToNetwork()
            }

            self.resumeDownload()
        }

        print("\nOoops! Something went wrong: \(error.localizedDescription)")

        guard let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data else {
            return
        }

        self.resumeData = resumeData
    }
}
