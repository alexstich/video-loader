//
//  Manager for loading, prefetching and caching videos
//  AGVideoLoader.swift
//
//  Created by Алексей Гребенкин on 14.02.2023.
//  Copyright avgrebenkin© 2023. All rights reserved.
//

import Foundation
import AVFoundation

public class AGVideoLoader
{
    public var cachingModeOn: Bool = true
    
    internal var prefetchingModeOn: Bool = true
    
    public var debugModeOn: Bool = false {
        didSet{
            AGLogHelper.debugModeOn = debugModeOn
        }
    }
    
    public var cacheConfig: AGCacheProviderConfig!
    {
        didSet {
            cacheProvider.config = cacheConfig
        }
    }
    public var prefetchingConf: AGPrefetchProviderConfig!
    {
        didSet{
            prefetchingProvider.config = prefetchingConf
        }
    }
    
    private var cacheProvider: AGCacheProvider!
    public var prefetchingProvider: AGPrefetchProvider!
    
    static public let getInstance: AGVideoLoader = AGVideoLoader()
    
    static internal let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    private init()
    {
        self.cacheProvider = AGCacheProvider()
        self.prefetchingProvider = AGPrefetchProvider()
        self.prefetchingProvider.cacheProvider = self.cacheProvider
    }
    
    public func loadVideo(url: URL, indexPath: IndexPath? = nil, completion: ((AVAsset?)->Void)?)
    {
        
//        AGLogHelper.instance.printToConsole("Список в очереди prefetch - \(String(describing: self.prefetchingProvider.loadingOperations))")
//        AGLogHelper.instance.printToConsole("Список в очереди cache - \(String(describing: self.cacheProvider.cachePrepairedList))")
        
        cacheProvider.getCachedFilesList()
        
        AGLogHelper.instance.printToConsole("Надо загрузить indexPath - \(String(describing: indexPath)) url - \(url.path.suffix(10))")
        
        var final_completion: ((AVAsset?)->Void)? = completion
        
        if cachingModeOn {
            
            final_completion = { [weak self] asset in
                AGLogHelper.instance.printToConsole("Передали asset в player - \(String(describing: indexPath)) url - \(url.path.suffix(10))")
                completion?(asset)
                self?.cacheProvider.store(asset: asset as! AVURLAsset)
            }
            
            if let cacheUrl = cacheProvider.checkCacheExisting(url: url) {
                let asset = AVAsset(url: cacheUrl)
                final_completion?(asset)
                if indexPath != nil {
                    prefetchingProvider.deleteOperation(for: indexPath!)
                }
                AGLogHelper.instance.printToConsole("Загрузили из cache - \(cacheUrl.path.suffix(10))")
                return
            }
        }
        
        if indexPath != nil && prefetchingModeOn {
            if let operation = prefetchingProvider.getExistedOperation(for: indexPath!) {
                prefetchingProvider.setOperationHandler(operation: operation, indexPath: indexPath!, completion: final_completion)
                if let asset = operation.asset {
                    AGLogHelper.instance.printToConsole("Asset уже загружен в prefetch используем его - " + String("\(url.path.suffix(10))"))
                    operation.loadingCompleteHandler?(asset)
                }
            } else {
                
//                if cacheProvider.checkCachePrepairing(url: url) {
//                    cacheProvider.setHandler(url: url){ asset in
//                        final_completion?(asset)
//
//                    }
//                    AGLogHelper.instance.printToConsole("Назначили handler для cache - \(url.path.suffix(10))")
//                    return
//                }
                
                AGLogHelper.instance.printToConsole("Не нашли ничего делаем prefetch - " + String("\(url.path.suffix(10))"))
                prefetchingProvider.createOperation(for: indexPath!, completion: final_completion)
            }
            
            return
        }
        
        loadVideo(url: url, completion: final_completion)
    }
        
    func loadVideo(url: URL, completion: ((AVAsset?)->Void)?)
    {
        let asset_ = AVAsset(url: url)
        
        asset_.loadValuesAsynchronously(forKeys: AGVideoLoader.assetKeysRequiredToPlay) { [weak self] in
                        
            guard self != nil else { return }
            
            for key in AGVideoLoader.assetKeysRequiredToPlay {
                
                var error: NSError?
                
                if asset_.statusOfValue(forKey: key, error: &error) == .failed {
                    return
                }
            }

            if !asset_.isPlayable || asset_.hasProtectedContent {
                return
            }
            
            AGLogHelper.instance.printToConsole("Loading operation loaded asset - \(url.path.suffix(10))")
            
            completion?(asset_)
        }
    }
    
    public func clearQueues()
    {
        self.prefetchingProvider.clearQueue()
    }
    
    public func clearCache()
    {
        self.cacheProvider.clearCache()
    }
    
    public func setPrefetchSource(source: [IndexPath: URL])
    {
        self.prefetchingModeOn = true
        self.prefetchingProvider.setPrefetchSource(source: source)
    }
}
