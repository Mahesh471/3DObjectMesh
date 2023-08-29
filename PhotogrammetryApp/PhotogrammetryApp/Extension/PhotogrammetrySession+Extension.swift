//
//  PhotogrammetrySession+Extension.swift
//  PhotogrammetryApp
//
//  Created by Mahesh on 18/08/23.
//

import RealityKit

@available(macOS 12.0, *)
extension PhotogrammetrySession.Request.Detail {
    init(_ detail: String) throws {
        switch detail {
        case "preview": self = .preview
        case "reduced": self = .reduced
        case "medium": self = .medium
        case "full": self = .full
        case "raw": self = .raw
        default: throw IllegalOption.invalidDetail(detail)
        }
    }
}

@available(macOS 12.0, *)
extension PhotogrammetrySession.Configuration.SampleOrdering {
    init(sampleOrdering: String) throws {
        if sampleOrdering == "unordered" {
            self = .unordered
        } else if sampleOrdering == "sequential" {
            self = .sequential
        } else {
            throw IllegalOption.invalidSampleOrdering(sampleOrdering)
        }
    }
    
}

@available(macOS 12.0, *)
extension PhotogrammetrySession.Configuration.FeatureSensitivity {
    init(featureSensitivity: String) throws {
        if featureSensitivity == "normal" {
            self = .normal
        } else if featureSensitivity == "high" {
            self = .high
        } else {
            throw IllegalOption.invalidFeatureSensitivity(featureSensitivity)
        }
    }
}

private enum IllegalOption: Swift.Error {
    case invalidDetail(String)
    case invalidSampleOverlap(String)
    case invalidSampleOrdering(String)
    case invalidFeatureSensitivity(String)
}
