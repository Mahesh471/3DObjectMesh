//
//  ObjectCapturingAppApp.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import SwiftUI

@main
struct ObjectCapturingAppApp: App {
    @StateObject var model = CameraViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
