//
//  CameraViewModel.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import AVFoundation
import Combine
import CoreMotion
import SwiftUI

private let logger = getLogger(category: "CameraViewModel")

/// This is a observable data model class that holds all of the app's state
class CameraViewModel: ObservableObject {
    var session: AVCaptureSession
    
    /// This is capture mode
    enum CaptureMode {
        case manual
        case automatic(everySecs: Double)
    }
    
    @Published var lastCapture: Capture?
    @Published var isCameraAvailable: Bool = false
    @Published var isHighQualityMode: Bool = false
    @Published var isDepthDataEnabled: Bool = false
    @Published var isMotionDataEnabled: Bool = false
    @Published var captureFolderState: CaptureFolderState?
    @Published var captureMode: CaptureMode = .manual {
        willSet(newMode) {
            if case .automatic = captureMode {
                stopAutomaticCapture()
                triggerEveryTimer = nil
            }
        }
        didSet {
            if case .automatic(let intervalSecs) = captureMode {
                autoCaptureIntervalSecs = intervalSecs
                triggerEveryTimer = TriggerEveryTimer(
                    triggerEvery: autoCaptureIntervalSecs,
                    onTrigger: {
                        self.capturePhotoAndMetadata()
                    },
                    updateEvery: 1.0 / 30.0,
                    onUpdate: { timeLeft in
                        self.timeUntilCaptureSecs = timeLeft
                    })
            }
        }
    }
    
    @Published var isAutoCaptureActive: Bool = false
    @Published var timeUntilCaptureSecs: Double = 0
    
    var autoCaptureIntervalSecs: Double = 0
    
    var readyToCapture: Bool {
        return captureFolderState != nil &&
        captureFolderState!.captures.count < CameraViewModel.maxPhotosAllowed &&
        self.inProgressPhotoCaptureDelegates.count < 2
    }
    
    var captureDir: URL? {
        return captureFolderState?.captureDir
    }
    
    static let maxPhotosAllowed = 250
    static let recommendedMinPhotos = 30
    static let recommendedMaxPhotos = 200
    static let defaultAutomaticCaptureIntervalSecs: Double = 3.0
    
    init() {
        session = AVCaptureSession()
        startSetup()
    }
    
    /// This method handle capture mode
    func advanceToNextCaptureMode() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        switch captureMode {
        case .manual:
            captureMode = .automatic(everySecs: CameraViewModel.defaultAutomaticCaptureIntervalSecs)
        case .automatic(_):
            captureMode = .manual
        }
    }
    
    /// Called when user presses the capture button
    func captureButtonPressed() {
        switch captureMode {
        case .manual:
            capturePhotoAndMetadata()
        case .automatic:
            guard triggerEveryTimer != nil else { return }
            if triggerEveryTimer!.isRunning {
                stopAutomaticCapture()
            } else {
                startAutomaticCapture()
            }
        }
    }
    
    /// This method creates a new capture dictionary
    func requestNewCaptureFolder() {
        logger.log("Requesting new capture folder...")
        DispatchQueue.main.async {
            self.lastCapture = nil
        }
        
        sessionQueue.async {
            do {
                let newCaptureFolder = try CameraViewModel.createNewCaptureFolder()
                logger.log("Created new capture folder: \"\(String(describing: self.captureDir))\"")
                DispatchQueue.main.async {
                    logger.info("Publishing new capture folder: \"\(String(describing: self.captureDir))\"")
                    self.captureFolderState = newCaptureFolder
                }
            } catch {
                logger.error("Can't create new capture folder!")
            }
        }
    }
    
    func addCapture(_ capture: Capture) {
        logger.log("Received a new capture id=\(capture.id)")
        
        DispatchQueue.main.async {
            self.lastCapture = capture
        }
        
        guard self.captureDir != nil else {
            return
        }
        sessionQueue.async {
            do {
                // Write the files, then reload the folder to keep it in sync.
                try capture.writeAllFiles(to: self.captureDir!)
                self.captureFolderState?.requestLoad()
            } catch {
                logger.error("Can't write capture id=\(capture.id) error=\(String(describing: error))")
            }
        }
    }
    
    func removeCapture(captureInfo: CaptureInfo, deleteData: Bool = true) {
        logger.log("Remove capture called on \(String(describing: captureInfo))...")
        captureFolderState?.removeCapture(captureInfo: captureInfo, deleteData: deleteData)
    }
    
    /// This method starts the setup process
    func startSetup() {
        do {
            captureFolderState = try CameraViewModel.createNewCaptureFolder()
        } catch {
            setupResult = .cantCreateOutputDirectory
            logger.error("Setup failed!")
            return
        }
        
        requestAuthorizationIfNeeded()
        sessionQueue.async {
            self.configureSession()
        }
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates()
            DispatchQueue.main.async {
                self.isMotionDataEnabled = true
            }
        } else {
            logger.warning("Device motion data isn't available!")
            DispatchQueue.main.async {
                self.isMotionDataEnabled = false
            }
        }
    }
    
    func startSession() {
        dispatchPrecondition(condition: .onQueue(.main))
        logger.log("Starting session...")
        sessionQueue.async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }
    
    func pauseSession() {
        dispatchPrecondition(condition: .onQueue(.main))
        logger.log("Pausing session...")
        sessionQueue.async {
            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
        }
        if isAutoCaptureActive {
            stopAutomaticCapture()
        }
    }
    
    // MARK: Private State
    
    let previewWidth = 512
    let previewHeight = 512
    let thumbnailWidth = 512
    let thumbnailHeight = 512
    
    private var photoId: UInt32 = 0
    private var photoQualityPrioritizationMode: AVCapturePhotoOutput.QualityPrioritization =
        .quality
    private static let cameraShutterNoiseID: SystemSoundID = 1108
    
    private enum SessionSetupResult {
        case inProgress
        case success
        case cantCreateOutputDirectory
        case notAuthorized
        case configurationFailed
    }
    
    private enum SessionSetupError: Swift.Error {
        case cantCreateOutputDirectory
        case notAuthorized
        case configurationFailed
    }
    
    private enum SetupError: Error {
        case failed(msg: String)
    }
    
    /// This method processes the session setup results asynchronously
    private var setupResult: SessionSetupResult = .inProgress {
        didSet {
            logger.log("didSet setupResult=\(String(describing: self.setupResult))")
            if case .inProgress = setupResult { return }
            if case .success = setupResult {
                DispatchQueue.main.async {
                    self.isCameraAvailable = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
            }
        }
    }
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(label: "CameraViewModel: sessionQueue")
    private let motionManager = CMMotionManager()
    private var photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    private var triggerEveryTimer: TriggerEveryTimer?
    
    // MARK: - Private Functions
    
    private func capturePhotoAndMetadata() {
        logger.log("Capture photo called...")
        dispatchPrecondition(condition: .onQueue(.main))
        let videoPreviewLayerOrientation = session.connections[0].videoOrientation
        
        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
            }
            var photoSettings = AVCapturePhotoSettings()
            
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(
                    format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoDeviceInput!.device.isFlashAvailable {
                photoSettings.flashMode = .off
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
            
            photoSettings.embedsDepthDataInPhoto = true
            
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat =
                [kCVPixelBufferPixelFormatTypeKey:
                    photoSettings.__availablePreviewPhotoPixelFormatTypes.first!,
                           kCVPixelBufferWidthKey: self.previewWidth,
                          kCVPixelBufferHeightKey: self.previewHeight] as [String: Any]
                logger.log("Found available previewPhotoFormat: \(String(describing: photoSettings.previewPhotoFormat))")
            } else {
                logger.warning("Can't find preview photo formats!  Not setting...")
            }
            
            photoSettings.embeddedThumbnailPhotoFormat = [
                AVVideoCodecKey: AVVideoCodecType.jpeg,
                AVVideoWidthKey: self.thumbnailWidth,
                AVVideoHeightKey: self.thumbnailHeight
            ]
            
            DispatchQueue.main.async {
                self.isHighQualityMode = photoSettings.isHighResolutionPhotoEnabled
                && photoSettings.photoQualityPrioritization == .quality
            }
            
            self.photoId += 1
            let photoCaptureProcessor = self.makeNewPhotoCaptureProcessor(photoId: self.photoId,
                                                                          photoSettings: photoSettings)
            self.inProgressPhotoCaptureDelegates[
                photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            logger.log("inProgressCaptures=\(self.inProgressPhotoCaptureDelegates.count)")
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
    
    private func makeNewPhotoCaptureProcessor(
        photoId: UInt32, photoSettings: AVCapturePhotoSettings) -> PhotoCaptureProcessor {
            
            let photoCaptureProcessor = PhotoCaptureProcessor(
                with: photoSettings,
                model: self,
                photoId: photoId,
                motionManager: self.motionManager,
                willCapturePhotoAnimation: {
                    AudioServicesPlaySystemSound(CameraViewModel.cameraShutterNoiseID)
                },
                completionHandler: { photoCaptureProcessor in
                    self.sessionQueue.async {
                        self.inProgressPhotoCaptureDelegates.removeValue(
                            forKey: photoCaptureProcessor.requestedPhotoSettings.uniqueID)
                        logger.log("inProgressCaptures=\(self.inProgressPhotoCaptureDelegates.count)")
                    }
                }, photoProcessingHandler: { _ in
                }
            )
            return photoCaptureProcessor
        }
    
    /// This method starts the automatic capture timer
    private func startAutomaticCapture() {
        dispatchPrecondition(condition: .onQueue(.main))
        precondition(triggerEveryTimer != nil)
        
        logger.log("Start Auto Capture.")
        guard !triggerEveryTimer!.isRunning else {
            logger.error("Timer was already set!  Not setting again...")
            return
        }
        triggerEveryTimer!.start()
        isAutoCaptureActive = true
    }
    
    private func stopAutomaticCapture() {
        dispatchPrecondition(condition: .onQueue(.main))
        logger.log("Stop Auto Capture!")
        
        isAutoCaptureActive = false
        triggerEveryTimer?.stop()
    }
    
    private static func createNewCaptureFolder() throws -> CaptureFolderState {
        guard let newCaptureDir = CaptureFolderState.createCaptureDirectory() else {
            throw SetupError.failed(msg: "Can't create capture directory!")
        }
        return CaptureFolderState(url: newCaptureDir)
    }
    
    private func requestAuthorizationIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
    }
    
    private func configureSession() {
        guard setupResult == .inProgress else {
            logger.error("Setup failed, can't configure session!  result=\(String(describing: self.setupResult))")
            return
        }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .photo
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(
                device: getVideoDeviceForPhotogrammetry())
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                logger.error("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                return
            }
        } catch {
            logger.error("Couldn't create video device input: \(String(describing: error))")
            setupResult = .configurationFailed
            return
        }
        
        do {
            try addPhotoOutputOrThrow()
        } catch {
            logger.error("Error: adding photo output = \(String(describing: error))")
            setupResult = .configurationFailed
            return
        }
        
        DispatchQueue.main.async {
            self.isDepthDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            self.isHighQualityMode = self.photoOutput.isHighResolutionCaptureEnabled
            && self.photoOutput.maxPhotoQualityPrioritization == .quality
        }
        
        setupResult = .success
    }
    
    private func addPhotoOutputOrThrow() throws {
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            logger.error("Could not add photo output to the session")
            throw SessionSetupError.configurationFailed
        }
    }
    
    // This method checks for a depth-capable dual rear camera
    private func getVideoDeviceForPhotogrammetry() throws -> AVCaptureDevice {
        var defaultVideoDevice: AVCaptureDevice?
        
        if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video,
                                                          position: .back) {
            logger.log("Got back dual camera!")
            defaultVideoDevice = dualCameraDevice
        } else if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera,
                                                                     for: .video,
                                                                     position: .back) {
            logger.log("Got back dual wide camera!")
            defaultVideoDevice = dualWideCameraDevice
        } else if let backWideCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                     for: .video,
                                                                     position: .back) {
            logger.log("Can't find a depth-capable camera: using wide back camera!")
            defaultVideoDevice = backWideCameraDevice
        }
        
        guard let videoDevice = defaultVideoDevice else {
            logger.error("Back video device is unavailable.")
            throw SessionSetupError.configurationFailed
        }
        return videoDevice
    }
}
