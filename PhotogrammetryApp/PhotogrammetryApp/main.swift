//
//  main.swift
//  PhotogrammetryApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation
import os
import Metal

private let logger = getLogger(category: "Main")

private func supportsObjectReconstruction() -> Bool {
    for device in MTLCopyAllDevices() where
    !device.isLowPower &&
    device.areBarycentricCoordsSupported &&
    device.recommendedMaxWorkingSetSize >= UInt64(4e9) {
        return true
    }
    return false
}

private func supportsRayTracing() -> Bool {
    for device in MTLCopyAllDevices() where device.supportsRaytracing {
        return true
    }
    return false
}

func supportsObjectCapture() -> Bool {
    return supportsObjectReconstruction() && supportsRayTracing()
}

if #available(macOS 12.0, *) {
    Photogrammetry3DModel.main(
        ["/Users/admin/Documents/POC/3DObjectMesh/Object/Object_Data", "/Users/admin/Documents/POC/3DObjectMesh/Object/Object.usdz", "-d", "medium", "-o", "sequential", "-f", "normal"])
} else {
    fatalError("Requires minimum macOS 12.0!")
}
