//
//  ActivityViewWrapper.swift
//  ObjectCapturingApp
//
//  Created by Mahesh on 29/08/23.
//

import Foundation
import UIKit
import SwiftUI

private let logger = getLogger(category: "ActivityViewWrapper")

class ActivityViewWrapper: UIViewController {
    private var activityItems: [URL]
    private var applicationActivities: [UIActivity]?
    var isPresented: Binding<Bool>
    
    private var archiveUrl: URL?
    private var error: NSError?
    private let coordinator = NSFileCoordinator()
    private let activityView = UIActivityIndicatorView(style: .large)
    
    init(activityItems: [URL], applicationActivities: [UIActivity]? = nil, isPresented: Binding<Bool>) {
        self.activityItems = activityItems
        
        self.applicationActivities = applicationActivities
        self.isPresented = isPresented
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showActivityIndicatory()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        updateState()
    }
    
    private func showActivityIndicatory() {
        activityView.center = self.view.center
        self.view.addSubview(activityView)
        activityView.startAnimating()
    }
    
    func createZipFile() {
        coordinator.coordinate(readingItemAt: activityItems.first!, options: [.forUploading], error: &error) { (zipUrl) in
            do {
                let tempUrl = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: zipUrl, create: true).appendingPathComponent(Constant.Formats.archive)
                try FileManager.default.moveItem(at: zipUrl, to: tempUrl)
                archiveUrl = tempUrl
                logger.log("Archive folder path: \(tempUrl)")
            } catch {
                print(error)
            }
        }
    }
    
    private func updateState() {
        activityView.startAnimating()
        guard parent != nil else {return}
        let isActivityPresented = presentedViewController != nil
        if isActivityPresented != isPresented.wrappedValue {
            if !isActivityPresented {
                if let archiveUrl = archiveUrl {
                    let controller = UIActivityViewController(activityItems: [archiveUrl], applicationActivities: applicationActivities)
                    controller.popoverPresentationController?.sourceView = self.view
                    controller.excludedActivityTypes = [.addToReadingList,
                                                        .assignToContact,
                                                        .openInIBooks,
                                                        .postToVimeo,
                                                        .postToWeibo,
                                                        .postToFlickr,
                                                        .postToTwitter,
                                                        .postToFacebook,
                                                        .postToTencentWeibo]
                    controller.completionWithItemsHandler = { (_, _, _, _) in
                        self.isPresented.wrappedValue = false
                    }
                    present(controller, animated: true, completion: nil)
                } else {
                    self.createZipFile()
                }
            } else {
                self.presentedViewController?.dismiss(animated: true, completion: nil)
            }
        }
    }
}
