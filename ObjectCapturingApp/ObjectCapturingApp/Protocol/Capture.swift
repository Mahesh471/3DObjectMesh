//
//  ContentView.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation
import AVFoundation
import Combine
import CoreGraphics
import CoreImage
import CoreMotion
import UIKit

private let logger = getLogger(category: "Capture")

/// This is a data object that contains one image data
struct Capture: Identifiable {
    let id: UInt32
    let photo: AVCapturePhoto
    
    var previewUiImage: UIImage? {
        makePreview()
    }
    
    var depthData: Data?
    var gravity: CMAcceleration?
    
    var uiImage: UIImage {
        return UIImage(data: photo.fileDataRepresentation()!, scale: 1.0)!
    }
    
    init(id: UInt32, photo: AVCapturePhoto, depthData: Data? = nil,
         gravity: CMAcceleration? = nil) {
        self.id = id
        self.photo = photo
        self.depthData = depthData
        self.gravity = gravity
    }
    
    /// This method writes the captured images to a specified folder
    func writeAllFiles(to captureDir: URL) throws {
        writeImage(to: captureDir)
        writeGravityIfAvailable(to: captureDir)
        writeDepthIfAvailable(to: captureDir)
    }
    
    // MARK: Private Helpers
    
    private var photoIdString: String {
        return CaptureInfo.photoIdString(for: id)
    }
    
    private func makePreview() -> UIImage? {
        if let previewPixelBuffer = photo.previewPixelBuffer {
            let ciImage: CIImage = CIImage(cvPixelBuffer: previewPixelBuffer)
            let context: CIContext = CIContext(options: nil)
            let cgImage: CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
            return UIImage(cgImage: cgImage, scale: 1.0,
                           orientation: uiImage.imageOrientation)
        } else {
            return nil
        }
    }
    
    @discardableResult
    private func writeImage(to captureDir: URL) -> Bool {
        let imageUrl = CaptureInfo.imageUrl(in: captureDir, id: id)
        print("Saving: \(imageUrl.path)...")
        logger.log("Depth Data = \(String(describing: photo.depthData))")
        do {
            try photo.fileDataRepresentation()!
                .write(to: URL(fileURLWithPath: imageUrl.path), options: .atomic)
            return true
        } catch {
            logger.error("Can't write image to \"\(imageUrl.path)\" error=\(String(describing: error))")
            return false
        }
    }
    
    @discardableResult
    private func writeGravityIfAvailable(to captureDir: URL) -> Bool {
        guard let gravityVector = gravity else {
            return false
        }
        let gravityString =
        String(format: "%lf,%lf,%lf", gravityVector.x, gravityVector.y, gravityVector.z)
        let gravityUrl = CaptureInfo.gravityUrl(in: captureDir, id: id)
        logger.log("Writing gravity metadata to: \"\(gravityUrl.path)\"...")
        do {
            try gravityString.write(toFile: gravityUrl.path, atomically: true,
                                    encoding: .utf8)
            logger.log("Done.")
            return true
        } catch {
            logger.error(
                "can't write \(gravityUrl.path) error=\(String(describing: error))")
            return false
        }
    }
    
    @discardableResult
    private func writeDepthIfAvailable(to captureDir: URL) -> Bool {
        guard let depthMapData = depthData else {
            logger.warning("No depth data to save!")
            return false
        }
        
        let depthMapUrl = CaptureInfo.depthUrl(in: captureDir, id: id)
        logger.log("Writing depth data to path=\"\(depthMapUrl.path)\"...")
        do {
            try depthMapData.write(to: URL(fileURLWithPath: depthMapUrl.path), options: .atomic)
            return true
        } catch {
            logger.error("Can't write depth tiff to: \"\(depthMapUrl.path)\" error=\(String(describing: error))")
            return false
        }
    }
}
