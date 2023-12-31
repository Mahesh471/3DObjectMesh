//
//  CaptureFolderState.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Combine
import Foundation

private let logger = getLogger(category: "CaptureFolderState")

/// This class loads the contents of an image capture folder
class CaptureFolderState: ObservableObject {
    static private let workQueue = DispatchQueue(label: "CaptureFolderState.Work",
                                                 qos: .userInitiated)
    
    enum Error: Swift.Error {
        case invalidCaptureDir
    }
    
    @Published var captureDir: URL?
    @Published var captures: [CaptureInfo] = []
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(url captureDir: URL) {
        self.captureDir = captureDir
        requestLoad()
    }
    
    func requestLoad() {
        requestLoadCaptureInfo()
            .receive(on: DispatchQueue.main)
            .replaceError(with: [])
            .assign(to: \.captures, on: self)
            .store(in: &subscriptions)
    }
    
    /// This method requests the removal of a specific capture
    func removeCapture(captureInfo: CaptureInfo, deleteData: Bool = true) {
        logger.log("Request removal of captureInfo: \(String(describing: captureInfo))...")
        CaptureFolderState.workQueue.async {
            if deleteData {
                captureInfo.deleteAllFiles()
            }
            DispatchQueue.main.async {
                self.captures.removeAll(where: { $0.id == captureInfo.id })
            }
        }
    }
    
    private func requestLoadCaptureInfo() -> Future<[CaptureInfo], Error> {
        let future = Future<[CaptureInfo], Error> { promise in
            guard self.captureDir != nil else {
                promise(.failure(.invalidCaptureDir))
                return
            }
            CaptureFolderState.workQueue.async {
                var captureInfoResults: [CaptureInfo] = []
                do {
                    let imgUrls = try FileManager.default
                        .contentsOfDirectory(at: self.captureDir!, includingPropertiesForKeys: [],
                                             options: [.skipsHiddenFiles])
                        .filter { $0.isFileURL
                            && $0.lastPathComponent.hasSuffix(Constant.Formats.imageSuffix)
                        }
                    for imgUrl in imgUrls {
                        guard let photoIdString =
                                try? CaptureInfo.photoIdString(from: imgUrl) else {
                            logger.error("Can't get photoIdString from url: \"\(imgUrl)\"")
                            continue
                        }
                        guard let captureId = try? CaptureInfo.extractId(from: photoIdString) else {
                            logger.error("Can't get id from from photoIdString: \"\(photoIdString)\"")
                            continue
                        }
                        captureInfoResults.append(CaptureInfo(id: captureId,
                                                              captureDir: self.captureDir!))
                    }
                    captureInfoResults.sort(by: { $0.id < $1.id })
                    promise(.success(captureInfoResults))
                } catch {
                    promise(.failure(.invalidCaptureDir))
                    return
                }
            }
        }
        return future
    }
    
    // MARK: Static methods
    
    /// The method use to get documents folder, where all captures photos stores
    static func capturesFolder() -> URL? {
        guard let documentsFolder =
                try? FileManager.default.url(for: .documentDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil, create: false) else {
            return nil
        }
        return documentsFolder.appendingPathComponent("Captures/", isDirectory: true)
    }
    
    /// This method attempts to create a capture directory for outputting the images and metadata
    static func createCaptureDirectory() -> URL? {
        guard let capturesFolder = CaptureFolderState.capturesFolder() else {
            logger.error("Can't get user document dir!")
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let timestamp = formatter.string(from: Date())
        let newCaptureDir = capturesFolder
            .appendingPathComponent(timestamp + "/", isDirectory: true)
        
        logger.log("Creating capture path: \"\(String(describing: newCaptureDir))\"")
        let capturePath = newCaptureDir.path
        do {
            try FileManager.default.createDirectory(atPath: capturePath,
                                                    withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create capturepath=\"\(capturePath)\" error=\(String(describing: error))")
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: capturePath, isDirectory: &isDir)
        guard exists && isDir.boolValue else {
            return nil
        }
        return newCaptureDir
    }
    
    /// This method return instance that's populated with a list of capture folders sorted by creation date.
    static func requestCaptureFolderListing() -> Future<[URL], Never> {
        let future = Future<[URL], Never> { promise in
            workQueue.async {
                guard let docFolder = CaptureFolderState.capturesFolder() else {
                    promise(.success([]))
                    return
                }
                guard let folderListing =
                        try? FileManager.default
                    .contentsOfDirectory(at: docFolder,
                                         includingPropertiesForKeys: [.creationDateKey],
                                         options: [ .skipsHiddenFiles ]) else {
                    promise(.success([]))
                    return
                }
                // Sort by creation date, newest first.
                let sortedFolderListing = folderListing
                    .sorted { lhs, rhs in
                        creationDate(for: lhs) > creationDate(for: rhs)
                    }
                promise(.success(sortedFolderListing))
            }
        }
        return future
    }
    
    private static func creationDate(for url: URL) -> Date {
        let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
        
        if date == nil {
            logger.error("creation data is nil for: \(url.path).")
            return Date.distantPast
        } else {
            return date!
        }
    }
    
    /// This method requests the removal of the capture folder
    @discardableResult
    static func removeCaptureFolder(folder: URL) -> Future<Bool, Swift.Error> {
        logger.log("Removing folder: \"\(folder.path)\"")
        let future = Future<Bool, Swift.Error> { promise in
            workQueue.async {
                do {
                    try FileManager.default.removeItem(atPath: folder.path)
                    promise(.success(true))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        return future
    }
}
