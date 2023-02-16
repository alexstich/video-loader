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
    }
    
    public func loadVideo(url: URL, indexPath: IndexPath? = nil, completion: ((AVAsset?)->Void)?)
    {
        var final_completion: ((AVAsset?)->Void)? = completion
        
        if cachingModeOn {
            
            final_completion = { [weak self] asset in
                completion?(asset)
                self?.cacheProvider.store(asset: asset as! AVURLAsset)
            }
            
            if let cacheUrl = cacheProvider.checkCacheUrl(url: url) {
                
                let asset = AVAsset(url: cacheUrl)
                final_completion?(asset)
                
                AGLogHelper.instance.printToConsole("Загрузили из cache - \(cacheUrl.path.suffix(10))")
                
                return
            }
        }
        
        if indexPath != nil && prefetchingModeOn {
            if let operation = prefetchingProvider.getExistedOperation(for: indexPath!) {
                if let asset = operation.asset {
                    final_completion?(asset)
                } else {
                    operation.loadingCompleteHandler = final_completion
                }
            } else {
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
    
    func clearCache()
    {
        self.cacheProvider.clearCache()
    }
    
    func setPrefetchSource(source: [IndexPath: URL])
    {
        self.prefetchingModeOn = true
        self.prefetchingProvider.setPrefetchSource(source: source)
    }
}
