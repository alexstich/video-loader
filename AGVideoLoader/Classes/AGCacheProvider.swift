//
//  AGCacheProvider.swift
//
//  Created by  Aleksei Grebenkin on 13.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import AVFoundation

final class AGCacheProvider: NSObject, AVAssetResourceLoaderDelegate
{
    internal var config: AGCacheProviderConfig!
        
    private var cacheDirectory: URL?
    
    init(_ config: AGCacheProviderConfig? = nil)
    {
        if config != nil {
            self.config = config
        } else {
            self.config = AGCacheProviderConfig()
        }
        
        super.init()
        
        try? self.prepareStorageDirectory()
    }
    
    /// Creates if needed the cache directory
    private func prepareStorageDirectory() throws
    {
        guard cacheDirectory == nil else { return }
        
        var cacheURL = FileManager.default.urls(for: .cachesDirectory,in: .userDomainMask).first
        
        cacheURL = cacheURL?.appendingPathComponent("tech.avgrebenkin.\(config.cacheDirectoryName).cache", isDirectory: true)
        cacheURL = cacheURL?.appendingPathComponent("videos", isDirectory: true)
        
        guard let path = cacheURL?.path, !FileManager.default.fileExists(atPath: path) else { return cacheDirectory = cacheURL }
        guard (try? FileManager.default.createDirectory(at: cacheURL!, withIntermediateDirectories: true)) != nil else { return }
        
        cacheDirectory = cacheURL
    }

    /// Creates an output path
    ///
    /// - Parameters:
    ///   - url: file url for export
    private func getCacheURLPath(url: URL) -> URL? {

        var outputURL: URL?
        outputURL = cacheDirectory?.appendingPathComponent(url.lastPathComponent, isDirectory: false)
        return outputURL
    }
        
    private func freeCacheDirectorySpace(for data: Data) -> Bool
    {
//        let ceil__ = ceil(Float(data.count)/(1024*1024))
//        AGLogHelper.instance.printToConsole("New file space - \(ceil__)")
        
        guard self.cacheDirectory != nil else { return false }
        guard data.count < config.maxCacheDirectorySpace else { return false }
        
        var totalSpace = self.cacheDirectory!.folderSize()
        
//        let ceil_ = ceil(Float(config.maxCacheDirectorySpace)/(1024*1024)) - ceil(Float(totalSpace)/(1024*1024))
//        AGLogHelper.instance.printToConsole("Total space before store to cache - \(ceil_)")
        
        if (totalSpace + data.count) > config.maxCacheDirectorySpace {
            if var directoryContents = try? FileManager.default.contentsOfDirectory(
                at: self.cacheDirectory!,
                includingPropertiesForKeys: [.totalFileSizeKey]
            ) {
                
                directoryContents.sort(by: { (url_a, url_b) in
                    return url_a.creationDate()! <= url_b.creationDate()!
                })
                
                for url in directoryContents {
                    
                    AGLogHelper.instance.printToConsole("File need to remove - \(url.path.suffix(10)) - \(String(describing: url.creationDate()))")
                    
                    let values = try? url.resourceValues(forKeys: [.totalFileSizeKey])
                    let size = values?.totalFileSize
                    
                    if size != nil {
                        totalSpace -= size!
                        try? FileManager.default.removeItem(atPath: url.path)
                        
                        let ceil = ceil(Float(totalSpace)/(1024*1024))
                        AGLogHelper.instance.printToConsole("Total space after removing file - \(ceil)")
                
                        if (totalSpace + data.count) < config.maxCacheDirectorySpace {
                            break
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func checkCacheExisting(url: URL) -> URL?
    {
        guard let cacheURLPath = self.getCacheURLPath(url: url) else { return nil }
        guard FileManager.default.fileExists(atPath: cacheURLPath.path) else { return nil }
        
        return cacheURLPath
    }

    func store(asset: AVURLAsset, completion: ((AVAsset)->Void)? = nil)
    {
        guard self.cacheDirectory != nil else { return }
        guard self.checkCacheExisting(url: asset.url) == nil else { return }
        guard let cacheURLPath = self.getCacheURLPath(url: asset.url) else { return }
                
        AGLogHelper.instance.printToConsole("Try to cache asset  \(asset.url.path.suffix(10))")
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            
            guard let self = self else { return }
            
            let data = try? Data(contentsOf: asset.url)
            guard data != nil, self.freeCacheDirectorySpace(for: data!) else { return }
            let result = FileManager.default.createFile(atPath: cacheURLPath.path , contents: data, attributes: nil)
            
            let asset = AVAsset(url: cacheURLPath)
            completion?(asset)
                        
            AGLogHelper.instance.printToConsole("Assets cached  \(cacheURLPath.path.suffix(10)) - \(result)")
        }
    }
    
    func clearCache()
    {
        guard self.cacheDirectory != nil else { return }
                
        let totalSpace = self.cacheDirectory!.folderSize()
        let ceil_ = ceil(Float(totalSpace/(1024*1024)))
        AGLogHelper.instance.printToConsole("Space before clearing cache - \(ceil_)")
        
        try? FileManager.default.removeItem(atPath: self.cacheDirectory!.path)
    }
    
    func getCachedFilesList()
    {
        guard self.cacheDirectory != nil else { return }
        
        AGLogHelper.instance.printToConsole("Файлы в кэшэ:")
        
        if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory!.absoluteString) {
            for file in files {
                AGLogHelper.instance.printToConsole("File in cache - \(file)")
            }
        }
    }
}
