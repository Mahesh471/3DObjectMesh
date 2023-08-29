//
//  Constant.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation

struct Constant {
    struct Text {
        static let newSession = "New Session"
        static let depth = "Depth"
        static let gravity = "Gravity"
        static let captures = "Captures"
        static let scan = "Scan"
        static let autoCapture = "Auto Capture"
        static let share = "Share"
    }
    
    struct Formats {
        static let photoStringPrefix = "IMG_"
        static let imageSuffix: String = ".HEIC"
        static let gravitySuffix: String = "_gravity.TXT"
        static let depthSuffix: String = "_depth.TIF"
        static let archive: String = "archive.zip"
    }
}
