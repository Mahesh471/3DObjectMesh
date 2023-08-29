//
//  ShareView.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 29/08/23.
//

import SwiftUI
import os

private let logger = getLogger(category: "ShareView")

struct ShareView: View {
    @State private var isActivityPresented = false
    
    @ObservedObject var model: CameraViewModel
    @ObservedObject var captureFolderState: CaptureFolderState
    let usingCurrentCaptureFolder: Bool
    
    init(model: CameraViewModel) {
        self.model = model
        self.captureFolderState = model.captureFolderState!
        self.usingCurrentCaptureFolder = true
    }
    
    init(model: CameraViewModel, observing captureFolderState: CaptureFolderState) {
        self.model = model
        self.captureFolderState = captureFolderState
        usingCurrentCaptureFolder = (model.captureFolderState?.captureDir?.lastPathComponent
                                     == captureFolderState.captureDir?.lastPathComponent)
    }
    
    var body: some View {
        Button(Constant.Text.share) {
            self.isActivityPresented = true
            logger.log("Current folder \(String(describing: captureFolderState.captureDir?.lastPathComponent))")
        }.sheet(isPresented: $isActivityPresented) {
            ActivityView(activityItems: [captureFolderState.captureDir!], isPresented: $isActivityPresented)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [URL]
    var applicationActivities: [UIActivity]?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> ActivityViewWrapper {
        ActivityViewWrapper(activityItems: activityItems, applicationActivities: applicationActivities, isPresented: $isPresented)
    }
    
    func updateUIViewController(_ uiViewController: ActivityViewWrapper, context: Context) {
        uiViewController.isPresented = $isPresented
        uiViewController.createZipFile()
    }
}
