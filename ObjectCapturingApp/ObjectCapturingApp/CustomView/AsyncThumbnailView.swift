//
//  AsyncThumbnailView.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import SwiftUI

// Thumbnail view
struct AsyncThumbnailView: View {
    let url: URL
    
    @StateObject private var imageStore: AsyncImageStore
    
    init(url: URL) {
        self.url = url
        _imageStore = StateObject(wrappedValue: AsyncImageStore(url: url))
    }
    
    var body: some View {
        Image(uiImage: imageStore.thumbnailImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .onAppear {
                imageStore.loadThumbnail()
            }
    }
}
