//
//  VPCL+AVFoundation.swift
//  VideoPhotoCaptureLibrary
//
//  Created by Jake on 1/22/17.
//  Copyright © 2017 Jake. All rights reserved.
//

import AVFoundation

enum VPCLCaptureDeviceInputResult {
    case success(AVCaptureDeviceInput)
    case error(NSError)
}

extension AVCaptureSession {
    func vpcl_addOutput(_ output: AVCaptureOutput) {
        if canAddOutput(output) {
            addOutput(output)
        }
    }
    
    private func vpcl_addInput(_ input: AVCaptureInput) {
        if canAddInput(input) {
            addInput(input)
        }
        
    }
    
    func vpcl_addInput(with device: AVCaptureDevice, completion: ((VPCLCaptureDeviceInputResult) -> Void)? = nil) {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            vpcl_addInput(input)
            
            completion?(.success(input))
        } catch let error as NSError {
            assertionFailure("Error: \(error.localizedDescription)")
            
            completion?(.error(error))
        }
    }
}

extension AVCaptureDevice {
    public class func videoDevice(for position: AVCaptureDevicePosition = .back) -> AVCaptureDevice! {
        return AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                             mediaType: AVMediaTypeVideo,
                                             position: position)
    }
    
    public class func audioDevice() -> AVCaptureDevice? {
        // TODO: Verify whether front/back mics are exposed with this API
        //        return AVCaptureDevice.defaultDevice(withDeviceType: .builtInMicrophone,
        //                                             mediaType: AVMediaTypeAudio,
        //                                             position: .front)
        return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
    }
}
