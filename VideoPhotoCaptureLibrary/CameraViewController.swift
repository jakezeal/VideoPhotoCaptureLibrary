//
//  CameraViewController.swift
//  VideoPhotoCaptureLibrary
//
//  Created by Jake on 1/22/17.
//  Copyright © 2017 Jake. All rights reserved.
//
//TODO: Delete temp file directory from this view controller?

import UIKit
import AVFoundation

// MARK: - Camera View Controller Delegate
protocol CameraViewControllerDelegate: class {
    func didSingleTapCameraView(_ cameraView: UIView, at focusPoint: CGPoint)
    func didDoubleTapCameraView(_ cameraView: UIView, in cameraViewController: CameraViewController)
    func didFinishRecordingMovieToOutputFileAt(_ outputFileURL: URL!)
    func didCapturePhotoWithImage(_ image: UIImage)
}

class CameraViewController: UIViewController {
    
    // MARK: - Instance Vars
    weak var delegate: CameraViewControllerDelegate?
    lazy var videoQueue: DispatchQueue = { DispatchQueue(label: "com.jakezeal.VideoPhotoCaptureLibrary", qos: DispatchQoS.default) }()
    var tempMovieOutputFileURL: URL? {
        get {
            // FileManager.default.tempdirectory
            // UUId()
            //
            
            let tempDir = NSTemporaryDirectory()
            var url = URL(fileURLWithPath: tempDir)
            url.appendPathComponent("hsf_movie_\(UUID()).mov")
            return url
        }
    }
    
    fileprivate let captureSession = AVCaptureSession()
    lazy var previewLayer: AVCaptureVideoPreviewLayer! = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)!
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill
        layer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        return layer
    }()
    
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    var activeVideoInput: AVCaptureDeviceInput!
    
    fileprivate var flashIsOn = false
    
    let cameraTransitionView = UIView()
    let blurEffect = UIBlurEffect(style: .dark)
    var cameraTransitionViewBlur: UIVisualEffectView!
    
    // MARK: - View Lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add preview layer
        view.layer.addSublayer(previewLayer)
        
        setupTapGestureRecognizer()
        setupCameraSessionTransitions()
    }
    
    override func viewDidLayoutSubviews() {
        previewLayer.frame = view.bounds
    }
    
    deinit {
        stopCaptureSession()
    }
}

// MARK: - Setups
extension CameraViewController {
    fileprivate func setupTapGestureRecognizer() {
        
        // Single tap camera
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTappedCameraView(tap:)))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        // Double tap camera
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTappedCameraView))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }
}

// MARK: - Helpers
extension CameraViewController {
    func singleTappedCameraView(tap: UITapGestureRecognizer) {
        
        // Make sure we have capture device
        guard let captureDevice = AVCaptureDevice.videoDevice() else {
            return
        }
        
        // Get points of touch
        let touchPoint = tap.location(in: self.view)
        
        let x = touchPoint.y / view.bounds.height
        let y = 1.0 - touchPoint.x / view.bounds.width
        let focusPoint = CGPoint(x: x, y: y)
        
        // Focus on that point
        try? captureDevice.lockForConfiguration()
        captureDevice.focusPointOfInterest = focusPoint
        captureDevice.focusMode = .continuousAutoFocus
        captureDevice.exposurePointOfInterest = focusPoint
        captureDevice.exposureMode = .continuousAutoExposure
        captureDevice.unlockForConfiguration()
        
        delegate?.didSingleTapCameraView(view, at: touchPoint)
    }
    
    func doubleTappedCameraView() {
        delegate?.didDoubleTapCameraView(view, in: self)
    }
}

// MARK: - Camera Session Transitions
extension CameraViewController {
    
    fileprivate func setupCameraSessionTransitions() {
        
        // Set up camera transition view
        cameraTransitionView.frame = view.frame
        cameraTransitionView.backgroundColor = UIColor.black
        view.addSubview(cameraTransitionView)

        // Notifications
        
        // Camera session started
        NotificationCenter.default.addObserver(self, selector: #selector(cameraSessionStarted), name: Notification.Name.AVCaptureSessionDidStartRunning, object: nil)
        
        // Camera session stopped
        NotificationCenter.default.addObserver(self, selector: #selector(cameraSessionStopped), name: Notification.Name.AVCaptureSessionDidStopRunning, object: nil)
    }
    
    func cameraSessionStarted() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, delay: 0, options: [.allowUserInteraction], animations: { 
                self.cameraTransitionView.alpha = 0
            }, completion: nil)
        }
    }
    
    func cameraSessionStopped() {
        DispatchQueue.main.async {
            self.cameraTransitionView.alpha = 1
        }
    }
}

// MARK: - AVCaptureSession
extension CameraViewController {
    func isAudioAuthorized() -> Bool {
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio) ==  .authorized {
            return true
        } else {
            return false
        }
    }
    
    func isCameraAuthorized() -> Bool {
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) ==  .authorized {
            return true
        } else {
            return false
        }
    }
    
    func requestPermissionForAudio(_ completionHandler: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio) { (granted) in
            guard granted else { return }
            self.setupAudioCaptureSession()
            completionHandler()
        }
    }
    
    func requestPermissionForCamera(_ completionHandler: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { (granted) in
            guard granted else { return }
            self.setupCameraCaptureSession()
            completionHandler()
        }
    }
    
    func setupAudioCaptureSession() {
        if let audioDevice = AVCaptureDevice.audioDevice() {
            captureSession.vpcl_addInput(with: audioDevice)
        }
    }
    
    func setupCameraCaptureSession() {
        if let cameraDevice = AVCaptureDevice.videoDevice() {
            
            captureSession.vpcl_addInput(with: cameraDevice) { [unowned self] result in
                switch result {
                case .success(let deviceInput):
                    self.activeVideoInput = deviceInput
                case .error: break
                }
            }
        }
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh

//        let videoOutput = AVCaptureVideoDataOutput()
//        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        // captureSession.sessionPreset = AVCaptureSessionPresetMedium
        captureSession.vpcl_addOutput(photoOutput)
        captureSession.vpcl_addOutput(movieOutput)
    }
    
    func startCaptureSession() {
        guard !captureSession.isRunning else { return }
        
        videoQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    
    func stopCaptureSession() {
        guard captureSession.isRunning else { return }
        
        videoQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    func switchFlash() {
        switchFlash(on: !flashIsOn)
    }
    
    fileprivate func switchFlash(on: Bool) {
//        guard let newFlashMode = CameraFlashMode(rawValue: (flashMode.rawValue+1)%3) else { return flashMode }
//        flashMode = newFlashMode
//        return flashMode

//        if (captureDevice.position == AVCaptureDevicePosition.back) {
//            guard let avFlashMode = AVCaptureFlashMode(rawValue: flashMode.rawValue) else { continue }
//            if (captureDevice.isFlashModeSupported(avFlashMode)) {
//                do {
//                    try captureDevice.lockForConfiguration()
//                } catch {
//                    return
//                }
//                captureDevice.flashMode = avFlashMode
//                captureDevice.unlockForConfiguration()
//            }
//        }
        
        // If front facing
        if activeVideoInput.device.position == .front { return }
        
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else { return }
        guard device.hasTorch && device.hasFlash else { return }
        try! device.lockForConfiguration()
        try! device.setTorchModeOnWithLevel(1)
        
        device.torchMode = on == true ? .on : .off
        flashIsOn = on
        
        device.unlockForConfiguration()
    }
    
    func switchCamera() {
        // TODO: Considering using AVCaptureDeviceDiscoverySession to check for multiple cameras

        //ATTN: MOVED TO CAMERA VIEW CONTROLLER TO RESET CAPTURE BUTTON
//        guard !movieOutput.isRecording else {
//            movieOutput.stopRecording()
//            return
//        }
        
        captureSession.beginConfiguration()
        
        let newPosition: AVCaptureDevicePosition = activeVideoInput.device.position == .back ? .front : .back
        
        // Turn flash off if front
        if newPosition == .front {
            switchFlash(on: false)
        }
        
        // TODO: Make sure audio is setup when switching cameras
        //        setupAudioInput()
        if let cameraDevice = AVCaptureDevice.videoDevice(for: newPosition) {
            captureSession.removeInput(activeVideoInput)
            
            captureSession.vpcl_addInput(with: cameraDevice) { [unowned self] result in
                switch result {
                case .success(let deviceInput):
                    self.activeVideoInput = deviceInput
                case .error(let error):
                    print(error.localizedDescription)
                    break
                }
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    var activeVideoOrientation: AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .landscapeRight
        }
    }
    
    func updateZoom(withPercent percent: CGFloat) {
        var percent = percent
        // Get capture device
        var captureDevice: AVCaptureDevice
        if activeVideoInput.device.position == .front {
            captureDevice = AVCaptureDevice.videoDevice(for: .front)
            percent *= 0.07
        } else {
            captureDevice = AVCaptureDevice.videoDevice()
        }
        
        let maxScale = captureDevice.activeFormat.videoMaxZoomFactor - 1
        let newScale = percent * maxScale + 1
        
        try! captureDevice.lockForConfiguration()
        captureDevice.videoZoomFactor = newScale
        captureDevice.unlockForConfiguration()
    }
    
    func resetZoom() {
        updateZoom(withPercent: 0)
    }
    
    func capturePhoto() {
        // self.captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        guard let connection = photoOutput.connection(withMediaType: AVMediaTypeVideo)
            else { return }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = activeVideoOrientation
        }
        
        let settings = AVCapturePhotoSettings()
        // settings.flashMode = .on
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
    }
    
    func startVideoRecording() {
        // captureSession.sessionPreset = AVCaptureSessionPresetMedium
        
        guard let connection = movieOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
        
        connection.isVideoMirrored = activeVideoInput.device.position == .front ? true : false
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = activeVideoOrientation
        }
        
        // TODO: Enabling video stabilization introduces latency into the video capture pipeline
        //        if connection.isVideoStabilizationSupported {
        //            connection.preferredVideoStabilizationMode = .auto
        //        }
        
        guard let outputURL = tempMovieOutputFileURL else { return }
        
        movieOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
    }
    
    func stopVideoRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        guard let buffer = photoSampleBuffer,
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer),
            let image = UIImage(data: photoData)
            else { return }
        
        let orientedImage = activeVideoInput.device.position == .back ? image :  UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)
        delegate?.didCapturePhotoWithImage(orientedImage)
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        //
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        guard error == nil else {
            print(#function, error.localizedDescription)
            return
        }
        
        let urlAsset = AVURLAsset(url: outputFileURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetMediumQuality) else {
            return
        }
        
        exportSession.outputURL = tempMovieOutputFileURL        
        exportSession.outputFileType = AVFileTypeQuickTimeMovie
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously {
            self.delegate?.didFinishRecordingMovieToOutputFileAt(exportSession.outputURL)
        }
    }
}

//extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
//        
//    }
//}

