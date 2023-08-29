//
//  Logger.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation
import os

public func getLogger(category: String = " ") -> Logger {
    let logger = Logger(subsystem: "ObjectCapturingAppe",
                        category: category)
    return logger
}
