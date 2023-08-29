//
//  Logger.swift
//  PhotogrammetryApp
//
//  Created by Mahesh on 18/08/23.
//

import os

public func getLogger(category: String = " ") -> Logger {
    let logger = Logger(subsystem: "PhotogrammetryApp",
                                category: category)
    return logger
}
