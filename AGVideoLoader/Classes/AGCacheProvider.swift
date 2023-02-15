//
//  CacheManager.swift
//  Babydaika
//
//  Created by Алексей Гребенкин on 01.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import AVFoundation

class AGCacheProvider: NSObject, AVAssetResourceLoaderDelegate
{
    struct Config
    {
        var cacheDirectoryName: String = "AGCache"
        /// MB
        var maxCacheDirectorySpace: Int = 200 * 1024 * 1024
    }
    
    var config: Config!
    var cacheDirectory: URL?
    
    init(_ config: Config? = nil)
    {
        if config != nil {
            self.config = config
        } else {
            self.config = AGCacheProvider.Config()
        }
        
        super.init()
        
        try? self.prepareStorageDirectory()
    }
    
    func applyConfig(_ config: Config)
    {
        self.config = config
    }
    
    /// Creates if needed the cache directory
    func prepareStorageDirectory() throws {
        
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
    
    /// Creates an output path
    ///
    /// - Parameters:
    ///   - name: file name  for export
    private func getCacheURLPath(name: String) -> URL? {

        var outputURL: URL?
        outputURL = cacheDirectory?.appendingPathComponent(name, isDirectory: false)
        return outputURL
    }
    
    func checkCacheUrl(url: URL) -> URL?
    {
        guard let cacheURLPath = self.getCacheURLPath(url: url) else { return nil }
        guard FileManager.default.fileExists(atPath: cacheURLPath.path) else { return nil }
        
        return cacheURLPath
    }

    func store(asset: AVURLAsset)
    {
        guard self.cacheDirectory != nil else { return }
        guard let cacheURLPath = self.getCacheURLPath(url: asset.url) else { return }
        
        AGLogHelper.instance.printToConsole("Try to cache asset  \(asset.url.path.suffix(10))")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? Data(contentsOf: asset.url)
            guard data != nil, self.freeCacheDirectorySpace(for: data!) else { return }
            let result = FileManager.default.createFile(atPath: cacheURLPath.path , contents: data, attributes: nil)
            
            AGLogHelper.instance.printToConsole("Assets cached  \(asset.url.path.suffix(10)) - \(result)")
        }
    }
    
    func store(data: Data, name: String)
    {
        guard self.cacheDirectory != nil else { return }
        guard let cacheURLPath = self.getCacheURLPath(name: name) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            guard self.freeCacheDirectorySpace(for: data) else { return }
            let result = FileManager.default.createFile(atPath: cacheURLPath.path , contents: data, attributes: nil)
            
            AGLogHelper.instance.printToConsole("Assets cached  \(name) - \(result)")
        }
        
        
//        asset.resourceLoader.setDelegate(self, queue: .main)
//        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
//        exporter?.outputURL = cacheNamePathURL
//        exporter?.outputFileType = AVFileType.mp4
//
//        exporter?.exportAsynchronously(completionHandler: {
//            print("**** export work")
//            print(exporter?.status.rawValue)
//            print(exporter?.error)
//        })
    }
    
    func freeCacheDirectorySpace(for data: Data) -> Bool
    {
        let ceil__ = ceil(Float(data.count)/(1024*1024))
        AGLogHelper.instance.printToConsole("New file space - \(ceil__)")
        
        guard self.cacheDirectory != nil else { return false }
        guard data.count < config.maxCacheDirectorySpace else { return false }
        
        var totalSpace = self.cacheDirectory!.folderSize()
        
        let ceil_ = ceil(Float(config.maxCacheDirectorySpace)/(1024*1024)) - ceil(Float(totalSpace)/(1024*1024))
        AGLogHelper.instance.printToConsole("Total space before store to cache - \(ceil_)")
        
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
    
    func clearCache()
    {
        guard self.cacheDirectory != nil else { return }
                
        let totalSpace = self.cacheDirectory!.folderSize()
        let ceil_ = ceil(Float(totalSpace/(1024*1024)))
        AGLogHelper.instance.printToConsole("Space before clearing cache - \(ceil_)")
        
        try? FileManager.default.removeItem(atPath: self.cacheDirectory!.path)
    }
}


extension URL {
    public func directoryContents() -> [URL] {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
            return directoryContents
        } catch let error {
            print("Error: \(error)")
            return []
        }
    }

    public func folderSize() -> Int {
        let contents = self.directoryContents()
        var totalSize: Int = 0
        contents.forEach { url in
            let size = url.fileSize()
            totalSize += size
        }
        return totalSize
    }

    public func fileSize() -> Int {
        let attributes = URLFileAttribute(url: self)
        return attributes.fileSize ?? 0
    }
    
    public func creationDate() -> Date? {
        let attributes = URLFileAttribute(url: self)
        return attributes.creationDate
    }
}

// MARK: - URLFileAttribute
struct URLFileAttribute {
   private(set) var fileSize: Int? = nil
   private(set) var creationDate: Date? = nil
   private(set) var modificationDate: Date? = nil

   init(url: URL) {
       let path = url.path
       guard let dictionary: [FileAttributeKey: Any] = try? FileManager.default
               .attributesOfItem(atPath: path) else {
           return
       }

       if dictionary.keys.contains(FileAttributeKey.size),
           let value = dictionary[FileAttributeKey.size] as? Int {
           self.fileSize = value
       }

       if dictionary.keys.contains(FileAttributeKey.creationDate),
           let value = dictionary[FileAttributeKey.creationDate] as? Date {
           self.creationDate = value
       }

       if dictionary.keys.contains(FileAttributeKey.modificationDate),
           let value = dictionary[FileAttributeKey.modificationDate] as? Date {
           self.modificationDate = value
       }
   }
}
