//
//  AGVideoCacheManager.swift
//
//  Created by Алексей Гребенкин on 01.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import AVFoundation

final class AGVideoCacheManager: NSObject, AVAssetResourceLoaderDelegate
{
    static public var getInstance: AGVideoCacheManager = AGVideoCacheManager()
    
    struct Config
    {
        var name: String = "VideoCache"
        
        /// Max size of cache directory MB
        var maxCacheDirectorySpace: Int = 1024*1024*300 // 300 Mb
    }
    
    var config: Config!
    private var cacheDirectory: URL?
    
    init(_ config: Config? = nil)
    {
        if config != nil {
            self.config = config
        } else {
            self.config = AGVideoCacheManager.Config()
        }
        
        super.init()
        
        try? self.prepareStorageDirectory()
    }
    
    /// Creates the storage folder
    private func prepareStorageDirectory() throws {
        
        var cacheURL = FileManager.default.urls(for: .cachesDirectory,in: .userDomainMask).first
        
        cacheURL = cacheURL?.appendingPathComponent("tech.avgrebenkin.\(config.name).cache", isDirectory: true)
        cacheURL = cacheURL?.appendingPathComponent("videos", isDirectory: true)
        
        guard let path = cacheURL?.path, !FileManager.default.fileExists(atPath: path) else { return cacheDirectory = cacheURL }
        guard (try? FileManager.default.createDirectory(at: cacheURL!, withIntermediateDirectories: true)) != nil else { return }
        
        cacheDirectory = cacheURL
    }

    /// Creates an output path
    ///
    /// - Parameters:
    ///   - url: file url for export
    func getCacheNamePathURL(url: URL) -> URL? {

        var outputURL: URL?
        outputURL = cacheDirectory?.appendingPathComponent(url.lastPathComponent, isDirectory: false)
        return outputURL
    }
    
    /// Creates an output path
    ///
    /// - Parameters:
    ///   - name: file name  for export
    func getCacheNamePathURL(name: String) -> URL? {

        var outputURL: URL?
        outputURL = cacheDirectory?.appendingPathComponent(name, isDirectory: false)
        return outputURL
    }
    
    /**
     Check еhe presence of cached files
     
     - Parameters:
        - url: url of remote resource
     - Returns: url if the file existed  or nil
     */
    func checkCacheUrl(url: URL) -> URL?
    {
        guard let cacheNamePathURL = self.getCacheNamePathURL(url: url) else { return nil }
        guard FileManager.default.fileExists(atPath: cacheNamePathURL.path) else { return nil }
        
        return cacheNamePathURL
    }

    /// Creates the storage folder
    ///
    /// - Parameters:
    ///   - name: file name  for export
    func store(asset: AVURLAsset)
    {
        guard self.cacheDirectory != nil else { return }
        guard let cacheNamePathURL = self.getCacheNamePathURL(url: asset.url) else { return }
        
        VLLog.instance.printToConsole("try cache  \(String(describing: asset.url))")
        
        DispatchQueue.global(qos: .userInitiated).async {
                        
            asset.resourceLoader.setDelegate(self, queue: .global(qos: .userInitiated))
            
            let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
            exporter?.outputURL = cacheNamePathURL
            exporter?.outputFileType = AVFileType.mp4
    
            exporter?.exportAsynchronously(completionHandler: { [weak exporter] in
                
                switch exporter!.status {
                case .unknown:
                    VLLog.instance.printToConsole("cached NO with error unknown \(asset.url.path.suffix(10))")
                    break
                case .waiting:
                    VLLog.instance.printToConsole("cached waiting \(asset.url.path.suffix(10))")
                    break
                case .exporting:
                    VLLog.instance.printToConsole("cached exporting \(asset.url.path.suffix(10))")
                    break
                case .completed:
                    VLLog.instance.printToConsole("cached !!!!!  \(asset.url.path.suffix(10))")
                    break
                case .failed:
                    VLLog.instance.printToConsole("cached NO with error failed \(asset.url.path.suffix(10))")
                    break
                case .cancelled:
                    VLLog.instance.printToConsole("cached NO with error cancelled \(asset.url.path.suffix(10))")
                    break
                @unknown default:
                    VLLog.instance.printToConsole("cached FATAL ERROR \(asset.url.path.suffix(10))")
                }
            })
        }
    }
    
    func store(data: Data, name: String, completion: ((URL)->Void)?)
    {
        guard self.cacheDirectory != nil else { return }
        guard let cacheNamePathURL = self.getCacheNamePathURL(name: name) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            
            guard self.freeCacheDirectorySpaceIfNeeded(for: data) else { return }
            let result = FileManager.default.createFile(atPath: cacheNamePathURL.path , contents: data, attributes: nil)
            
            completion?(cacheNamePathURL)
            
            VLLog.instance.printToConsole("Загрузили в кэш !!! - \(name) - \(result)")
        }
    }
    
    private func cacheContent()
    {
        if var directoryContents = try? FileManager.default.contentsOfDirectory(
            at: self.cacheDirectory!,
            includingPropertiesForKeys: [.totalFileSizeKey]
        ) {
            
            directoryContents.sort(by: { (url_a, url_b) in
                return url_a.creationDate()! <= url_b.creationDate()!
            })
            
            VLLog.instance.printToConsole("cache content: ")
//            directoryContents.map({ url in
//                VLLog.instance.printToConsole("file \(url.path.suffix(10)) - \(String(describing: url.creationDate())) - \(ceil(Float(url.fileSize()) / (1024 * 1024))) MB")
//            })
        }
    }
    
    private func freeCacheDirectorySpaceIfNeeded(for data: Data) -> Bool
    {
        let ceil__ = ceil(Float(data.count)/(1024*1024))
        VLLog.instance.printToConsole("file space - \(ceil__)")
        
        return freeCacheDirectorySpaceIfNeeded(file_size: data.count)
    }
    
    private func freeCacheDirectorySpaceIfNeeded(file_size: Int) -> Bool
    {
        guard self.cacheDirectory != nil else { return false }
        guard file_size < config.maxCacheDirectorySpace else { return false }
        
        var totalSpace = self.cacheDirectory!.folderSize()
        
        let ceil_ = ceil(Float(config.maxCacheDirectorySpace)/(1024*1024)) - ceil(Float(totalSpace)/(1024*1024))
        VLLog.instance.printToConsole("total max space before - \(ceil_)")
        
        if (totalSpace + file_size) > config.maxCacheDirectorySpace {
            if var directoryContents = try? FileManager.default.contentsOfDirectory(
                at: self.cacheDirectory!,
                includingPropertiesForKeys: [.totalFileSizeKey]
            ) {
                
                directoryContents.sort(by: { (url_a, url_b) in
                    return url_a.creationDate()! <= url_b.creationDate()!
                })
                
//                directoryContents.map({ url in
//                    VLLog.instance.printToConsole("file \(url.path.suffix(10)) - \(String(describing: url.creationDate())) - \(ceil(Float(url.fileSize()) / (1024 * 1024))) MB")
//                })
                
                for url in directoryContents {
                    
                    VLLog.instance.printToConsole("Clear cache")
                    
                    VLLog.instance.printToConsole("url for removing \(url.path.suffix(10)) - \(String(describing: url.creationDate()))")
                    
                    let values = try? url.resourceValues(forKeys: [.totalFileSizeKey])
                    let size = values?.totalFileSize
                    
                    if size != nil {
                        totalSpace -= size!
                        try? FileManager.default.removeItem(atPath: url.path)
                        
                        let ceil = ceil(Float(totalSpace)/(1024*1024))
                        VLLog.instance.printToConsole("after removing space - \(ceil)")
                        
                        if (totalSpace + file_size) < config.maxCacheDirectorySpace {
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
        VLLog.instance.printToConsole("Cache directori clear - \(ceil_) MB")
        
        try? FileManager.default.removeItem(atPath: self.cacheDirectory!.path)
    }
}


extension URL {
    public func directoryContents() -> [URL] {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
            return directoryContents
        } catch let error {
            VLLog.instance.printToConsole("Error: \(error)")
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
