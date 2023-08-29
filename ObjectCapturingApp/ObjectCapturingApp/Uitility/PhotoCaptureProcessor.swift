//
//  PhotoCaptureProcessor.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation
import AVFoundation
import CoreImage
import CoreMotion

private let logger = getLogger(category: "PhotoCaptureDelegate")

/// This class stores state and provide delegate for all callbacks during the capture process
class PhotoCaptureProcessor: NSObject {
    private let photoId: UInt32
    private let model: CameraViewModel
    
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    private let willCapturePhotoAnimation: () -> Void
    
    lazy var context = CIContext()
    
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    
    private let photoProcessingHandler: (Bool) -> Void
    
    private var maxPhotoProcessingTime: CMTime?
    
    private let motionManager: CMMotionManager
    
    private var photoData: AVCapturePhoto?
    private var depthMapData: Data?
    private var depthData: AVDepthData?
    private var gravity: CMAcceleration?
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         model: CameraViewModel,
         photoId: UInt32,
         motionManager: CMMotionManager,
         willCapturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void) {
        self.photoId = photoId
        self.model = model
        self.motionManager = motionManager
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
    }
    
    private func didFinish() {
        completionHandler(self)
    }
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start
        + resolvedSettings.photoProcessingTimeRange.duration
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
        
        if motionManager.isDeviceMotionActive {
            gravity = motionManager.deviceMotion?.gravity
            logger.log("Captured gravity vector: \(String(describing: self.gravity))")
        }
        
        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else {
            return
        }
        
        let oneSecond = CMTime(seconds: 1, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            photoProcessingHandler(true)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        photoProcessingHandler(false)
        
        if let error = error {
            print("Error capturing photo: \(error)")
            photoData = nil
        } else {
            
            photoData = photo
        }
        
        logger.log("DidFinishProcessingPhoto: photo=\(String(describing: photo))")
        if let depthData = photo.depthData?.converting(toDepthDataType:
                                                        kCVPixelFormatType_DisparityFloat32),
           let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) {
            let depthImage = CIImage( cvImageBuffer: depthData.depthDataMap,
                                      options: [ .auxiliaryDisparity: true ] )
            depthMapData = context.tiffRepresentation(of: depthImage,
                                                      format: .Lf,
                                                      colorSpace: colorSpace,
                                                      options: [.disparityImage: depthImage])
        } else {
            logger.error("colorSpace .linearGray not available... can't save depth data!")
            depthMapData = nil
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        print("DidFinishCapture!")
        
        defer { didFinish() }
        
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            return
        }
        
        print("Making capture and adding to model...")
        model.addCapture(Capture(id: photoId, photo: photoData, depthData: depthMapData,
                                 gravity: gravity))
    }
}
