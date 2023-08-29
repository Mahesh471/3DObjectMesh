//
//  AsyncImageStore.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 18/08/23.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

/// This class handles image loading
class AsyncImageStore: ObservableObject {
    var url: URL
    
    @Published var thumbnailImage: UIImage
    @Published var image: UIImage
    
    private var subscriptions: Set<AnyCancellable> = []
    private let errorImage: UIImage
    
    init(url: URL, loadingImage: UIImage = UIImage(systemName: "questionmark.circle")!,
         errorImage: UIImage = UIImage(systemName: "xmark.circle")!) {
        self.url = url
        self.thumbnailImage = loadingImage
        self.image = loadingImage
        self.errorImage = errorImage
    }
    
    /// This method use to load of the thumbnail image
    func loadThumbnail() {
        ImageLoader.loadThumbnail(url: url)
            .receive(on: DispatchQueue.main)
            .replaceError(with: errorImage)
            .assign(to: \.thumbnailImage, on: self)
            .store(in: &subscriptions)
    }
    
    /// This method use to load of the full-size image.
    func loadImage() {
        ImageLoader.loadImage(url: url)
            .receive(on: DispatchQueue.main)
            .replaceError(with: errorImage)
            .assign(to: \.image, on: self)
            .store(in: &subscriptions)
    }
}
