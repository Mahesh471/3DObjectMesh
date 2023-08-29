//
//  CaptureInfo.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation
import Combine

private let logger = getLogger(category: "CaptureInfo")

/// This holds data object of captured photo
struct CaptureInfo: Identifiable {
    
    struct FileExistence {
        var image: Bool = false
        var depth: Bool = false
        var gravity: Bool = false
    }
    
    enum Error: Swift.Error {
        case invalidPhotoString
        case noSuchDirectory(URL)
    }
    
    let id: UInt32
    let captureDir: URL
    
    init(id: UInt32, captureDir: URL) {
        self.id = id
        self.captureDir = captureDir
    }
    
    var photoIdString: String {
        return CaptureInfo.photoIdString(for: id)
    }
    
    var imageUrl: URL {
        return CaptureInfo.imageUrl(in: captureDir, id: id)
    }
    
    var depthUrl: URL {
        return CaptureInfo.depthUrl(in: captureDir, id: id)
    }
    
    var gravityUrl: URL {
        return CaptureInfo.gravityUrl(in: captureDir, id: id)
    }
    
    /// This method checks for the existence of the image in all captured data
    func checkFilesExist() -> Future<FileExistence, CaptureInfo.Error> {
        let future = Future<FileExistence, CaptureInfo.Error> { promise in
            CaptureInfo.loaderQueue.async {
                guard CaptureInfo.doesDirectoryExist(url: captureDir) else {
                    logger.error("checkFilesExist: can't find dir \(captureDir)!")
                    promise(.failure(CaptureInfo.Error.noSuchDirectory(captureDir)))
                    return
                }
                do {
                    let existence = try CaptureInfo.checkFilesExist(inFolder: captureDir, id: id)
                    promise(.success(existence))
                } catch {
                    logger.error("checkFilesExist: error \(String(describing: error))!")
                    promise(.failure(CaptureInfo.Error.noSuchDirectory(captureDir)))
                }
            }
        }
        return future
    }
    
    /// This method deletes all data
    func deleteAllFiles() {
        dispatchPrecondition(condition: .notOnQueue(.main))
        deleteHelper(delete: imageUrl, fileType: "image")
        deleteHelper(delete: depthUrl, fileType: "depth")
        deleteHelper(delete: gravityUrl, fileType: "gravity")
    }
    
    private func deleteHelper(delete: URL, fileType: String) {
        do {
            logger.log("Deleting \(fileType) at \"\(delete.path)\"...")
            try FileManager.default.removeItem(atPath: delete.path)
            logger.log("Deleted \"\(delete.path)\".")
        } catch {
            logger.error("Can't delete \(fileType) \"\(delete.path)\" error=\(String(describing: error))")
        }
    }
    
    /// This method use to check files already exist in a specified capture directory
    static func checkFilesExist(inFolder captureDir: URL, id: UInt32) throws -> FileExistence {
        dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
        
        guard CaptureInfo.doesDirectoryExist(url: captureDir) else {
            throw Error.noSuchDirectory(captureDir)
        }
        
        var result = FileExistence()
        result.image = FileManager.default.fileExists(atPath: imageUrl(in: captureDir, id: id).path)
        result.depth = FileManager.default.fileExists(atPath: depthUrl(in: captureDir, id: id).path)
        result.gravity = FileManager.default.fileExists(
            atPath: gravityUrl(in: captureDir, id: id).path)
        return result
    }
    
    static private func doesDirectoryExist(url: URL) -> Bool {
        guard url.isFileURL else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path,
                                             isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
    
    /// This method extracts the image
    static func extractId(from photoString: String) throws -> UInt32 {
        guard let endOfPrefix = photoString.lastIndex(of: "_") else {
            throw Error.invalidPhotoString
        }
        let imgPrefix = photoString[...endOfPrefix]
        guard imgPrefix == Constant.Formats.photoStringPrefix else {
            throw Error.invalidPhotoString
        }
        guard let id = UInt32(photoString[photoString.index(after: endOfPrefix)...]) else {
            throw Error.invalidPhotoString
        }
        return id
    }
    
    /// This method returns the name for a captured image
    static func photoIdString(for id: UInt32) -> String {
        return String(format: "%@%04d", Constant.Formats.photoStringPrefix, id)
    }
    
    static func photoIdString(from imageUrl: URL) throws -> String {
        let basename = imageUrl.lastPathComponent
        guard basename.hasSuffix(Constant.Formats.imageSuffix), let suffixStartIndex = basename.lastIndex(of: ".") else {
            throw Error.invalidPhotoString
        }
        return String(basename[..<suffixStartIndex])
    }
    
    /// This method returns the file URL for the image data
    static func imageUrl(in captureDir: URL, id: UInt32) -> URL {
        return captureDir.appendingPathComponent(photoIdString(for: id).appending(Constant.Formats.imageSuffix))
    }
    
    /// This method returns the file URL for the gravity data
    static func gravityUrl(in captureDir: URL, id: UInt32) -> URL {
        return captureDir.appendingPathComponent(photoIdString(for: id).appending(Constant.Formats.gravitySuffix))
    }
    
    /// This method returns the file URL for the depth data
    static func depthUrl(in captureDir: URL, id: UInt32) -> URL {
        return captureDir.appendingPathComponent(photoIdString(for: id).appending(Constant.Formats.depthSuffix))
    }
    
    /// Serial queue for all file system access
    private static let loaderQueue =
    DispatchQueue(label: "com.apple.example.CaptureSample.CaptureInfo.loaderQueue",
                  qos: .userInitiated)
}
