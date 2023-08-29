//
//  CaptureFolderState.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import Foundation
import Combine
import SwiftUI

private let logger = getLogger(category: "CaptureFoldersView")

struct CaptureFoldersView: View {
    @ObservedObject var model: CameraViewModel
    @State var captureFolders: [URL] = []
    private var publisher: AnyPublisher<[URL], Never> {
        CaptureFolderState.requestCaptureFolderListing()
            .receive(on: DispatchQueue.main)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
    
    var body: some View {
        ZStack {
            Color(red: 0, green: 0, blue: 0.001, opacity: 1).edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
            List {
                ForEach(captureFolders, id: \.self) { folder in
                    CaptureFolderItem(model: model, url: folder)
                }
                .onDelete(perform: { indexSet in
                    let foldersToDelete = indexSet.map { captureFolders[$0] }
                    for folderToDelete in foldersToDelete {
                        logger.log("Removing: \(folderToDelete)")
                        CaptureFolderState.removeCaptureFolder(folder: folderToDelete)
                    }
                    captureFolders.remove(atOffsets: indexSet)
                })
            }
            .onReceive(publisher, perform: { folderListing in
                self.captureFolders = folderListing.filter {
                    $0.lastPathComponent != model.captureDir!.lastPathComponent
                }
            })
        }
        .navigationTitle(Constant.Text.captures)
        .navigationBarHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                EditButton()
            }
        }
    }
}

struct CaptureFolderItem: View {
    private let thumbnailWidth: CGFloat = 50
    private let thumbnailHeight: CGFloat = 50
    
    @ObservedObject private var model: CameraViewModel
    @StateObject private var ownedCaptureFolderState: CaptureFolderState
    
    init(model: CameraViewModel, url: URL) {
        self.model = model
        self._ownedCaptureFolderState = StateObject(wrappedValue: CaptureFolderState(url: url))
    }
    
    var body: some View {
        NavigationLink(destination: CaptureGalleryView(model: model,
                                                       observing: ownedCaptureFolderState)) {
            HStack {
                if !ownedCaptureFolderState.captures.isEmpty {
                    AsyncThumbnailView(url: ownedCaptureFolderState.captures[0].imageUrl)
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    Image(systemName: "xmark.rectangle")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .padding(8)
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading) {
                    Text(ownedCaptureFolderState.captureDir!.lastPathComponent)
                    Text("\(ownedCaptureFolderState.captures.count) images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}