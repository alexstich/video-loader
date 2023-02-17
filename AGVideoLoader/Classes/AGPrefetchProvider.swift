//
//  Manager prefetching videos
//  AGPrefetchProvider.swift
//
//  Created by  Aleksei Grebenkin on 13.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

final public class AGPrefetchProvider: NSObject, UITableViewDataSourcePrefetching
{
    weak var cacheProvider: AGCacheProvider!
    
    internal var config: AGPrefetchProviderConfig! {
        didSet{
            loadingQueue.maxConcurrentOperationCount = config.maxConcurrentOperationCount
        }
    }
        
    private var source: [IndexPath: URL] = [IndexPath: URL]() {
        didSet{
            AGLogHelper.instance.printToConsole("Add sources. Total items - " + String("\(source.count)"))
        }
    }
    
    private var loadingOperations: [Int: AGOperation] = [Int: AGOperation]()
    private var loadingQueue: OperationQueue = OperationQueue()
    
    init(_ config: AGPrefetchProviderConfig? = nil)
    {
        if config != nil {
            self.config = config
        } else {
            self.config = AGPrefetchProviderConfig()
        }
        
        super.init()
    }
    
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath])
    {
        for indexPath in indexPaths {
            if let url = source[indexPath], !self.operationExists(for: indexPath), cacheProvider.checkCacheExisting(url: url) == nil, !cacheProvider.checkCachePrepairing(url: url) {
                self.createOperation(for: indexPath, completion: nil)
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath])
    {
        for indexPath in indexPaths {
            self.deleteOperation(for: indexPath)
        }
    }
    
    func setPrefetchSource(source: [IndexPath: URL])
    {
        self.source = source
    }
    
    func clearQueue()
    {
        loadingOperations = [Int: AGOperation]()
        loadingQueue.cancelAllOperations()
    }
    
    func setOperationHandler(operation: AGOperation, indexPath: IndexPath, completion: ((AVAsset?)->Void)? = nil)
    {
        operation.loadingCompleteHandler = { /*[weak self] */asset in
            completion?(asset)
//            self?.deleteOperation(for: indexPath)
        }
    }
    
    func getExistedOperation(for indexPath: IndexPath) -> AGOperation?
    {
        guard let url = source[indexPath] else { return nil }
        
        let urlHash = url.absoluteString.hash
        
        return loadingOperations[urlHash]
    }
    
    func createOperation(for indexPath: IndexPath, completion: ((AVAsset?)->Void)?)
    {
        guard let url = source[indexPath] else { return }
        
        AGLogHelper.instance.printToConsole("Sourse - " + String(describing: source))
        
        let urlHash = url.absoluteString.hash
        
        let operation = AGOperation(url)
        operation.loadingCompleteHandler = completion
        loadingQueue.addOperation(operation)
        loadingOperations[urlHash] = operation
        
        AGLogHelper.instance.printToConsole("Added loading operation to queue - " + String("\(url.absoluteString.suffix(10))"))
    }
    
    private func operationExists(for indexPath: IndexPath) -> Bool
    {
        guard let url = source[indexPath] else { return false }
        
        let urlHash = url.absoluteString.hash
        
        return loadingOperations.keys.contains(urlHash)
    }
    
    func deleteOperation(for indexPath: IndexPath)
    {
        guard let url = source[indexPath] else { return }
        let urlHash = url.absoluteString.hash
        
        if let operation = self.getExistedOperation(for: indexPath) {
            
            AGLogHelper.instance.printToConsole("Deleted loading operation from queue - " + String("\(url.absoluteString.suffix(10))"))
            
            operation.cancel()

            loadingOperations.removeValue(forKey: urlHash)
        }
    }
}
