//
//  Manager prefetching videos
//  AGPrefetchProvider.swift
//
//  Created by Алексей Гребенкин on 13.02.2023.
//  Copyright © 2021 dimfcompany. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

//protocol AGVideoSourceProtocol
//{
//    func getVideoUrl() -> URL?
//}

class AGPrefetchProvider: NSObject, UITableViewDataSourcePrefetching
{
    struct Config
    {
        var maxConcurrentOperationCount: Int = 3
    }
        
    private var source: [IndexPath: URL] = [IndexPath: URL]() {
        didSet{
            AGLogHelper.instance.printToConsole("Add sources. Total items - " + String("\(source.count)"))
        }
    }
    
    private var loadingOperations: [Int: VideoLoadOperation] = [Int: VideoLoadOperation]()
    private var loadingQueue: OperationQueue = OperationQueue()
    
    override init()
    {
        super.init()
        
        loadingQueue.maxConcurrentOperationCount = 3
    }
    
    func applyConfig(_ config: Config)
    {
        loadingQueue.maxConcurrentOperationCount = config.maxConcurrentOperationCount
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath])
    {
        for indexPath in indexPaths {
            if self.operationExists(for: indexPath) {
                self.createOperation(for: indexPath, completion: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath])
    {
        for indexPath in indexPaths {
            self.deleteOperation(for: indexPath)
        }
    }
    
    func setPrefetchSource(source: [IndexPath: URL])
    {
        self.source = source
    }
//
//    func getExistingOperation(by url: URL) -> VideoLoadOperation?
//    {
//        return loadingOperations[url.absoluteString.hash]
//    }
    
    func operationExists(for url: URL) -> Bool
    {
        let urlHash = url.absoluteString.hash
        
        return loadingOperations.keys.contains(urlHash)
    }
    
    func operationExists(for indexPath: IndexPath) -> Bool
    {
        guard let url = source[indexPath] else { return false }
        
        let urlHash = url.absoluteString.hash
        
        return loadingOperations.keys.contains(urlHash)
    }
    
    func getExistedOperation(for indexPath: IndexPath) -> VideoLoadOperation?
    {
        guard let url = source[indexPath] else { return nil }
        
        let urlHash = url.absoluteString.hash
        
        return loadingOperations[urlHash]
    }
    
    internal func createOperation(for indexPath: IndexPath, completion: ((AVAsset?)->Void)?)
    {
        guard let url = source[indexPath] else { return }
        
        let urlHash = url.absoluteString.hash
        
        let operation = VideoLoadOperation(url)
        operation.loadingCompleteHandler = completion
        loadingQueue.addOperation(operation)
        loadingOperations[urlHash] = operation
        
        AGLogHelper.instance.printToConsole("Added loading operation to queue - " + String("\(url.absoluteString.hash)"))
    }
    
    private func deleteOperation(for indexPath: IndexPath)
    {
        guard let url = source[indexPath] else { return }
        let urlHash = url.absoluteString.hash
        
        if let operation = self.getExistedOperation(for: indexPath) {
            
            AGLogHelper.instance.printToConsole("Deleted loading operation from queue - " + String("\(url.absoluteString.suffix(10))"))
            
            operation.cancel()

            loadingOperations.removeValue(forKey: urlHash)
        }
    }
    
//    private func createOperation(from url: URL) -> VideoLoadOperation?
//    {
//        return VideoLoadOperation(url)
//    }
}

class VideoLoadOperation: Operation
{
    var asset: AVAsset?
    
    var loadingCompleteHandler: ((AVAsset?) -> Void)?
    
    private var url: URL?
    
    init(_ url: URL? = nil)
    {
        if url != nil {
            self.url = url!
        }
        
        super.init()
    }
    
    override func main()
    {
        if isCancelled { return }
        
        guard let url = self.url else { return }
        
        AGLogHelper.instance.printToConsole("Loading operation begin load asset - " + String("\(url.path.suffix(10))"))
        
        let asset_ = AVAsset(url: url)
        
        asset_.loadValuesAsynchronously(forKeys: PlayerView.assetKeysRequiredToPlay) { [weak self] in
                        
            guard let self = self else { return }
            
            for key in PlayerView.assetKeysRequiredToPlay {
                
                var error: NSError?
                
                if asset_.statusOfValue(forKey: key, error: &error) == .failed {
                    self.cancel()
                    return
                }
            }

            if !asset_.isPlayable || asset_.hasProtectedContent {
                self.cancel()
                return
            }
            
            AGLogHelper.instance.printToConsole("Loading operation loaded asset - \(url.path.suffix(10))")
            
            if self.isCancelled { return }
            
            self.asset = asset_
            self.loadingCompleteHandler?(asset_)
        }
    }
}
