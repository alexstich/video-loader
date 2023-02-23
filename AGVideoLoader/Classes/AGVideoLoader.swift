//
//  AGVideoLoader.swift
//
//  Created by Алексей Гребенкин on 09.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import AVFoundation

internal typealias VLLog = AGVideoLoaderLogHelper

final public class AGVideoLoader
{
    typealias VLStorage = AGVideoLoaderPlayersStorage
    
    static public let getInstance: AGVideoLoader = AGVideoLoader()
    
    var full_screen_mode: Bool = false
    
    private var loaderDelegate: AGVideoResourceLoaderDelegate!
    private var playersStorage = VLStorage()
    private var noCachedFileSize: Int = 1024*1024*20 // 20 MB
    
    private init(){}
    
    public func loadVideo(url: URL, file_lenghth: Int?, full_screen_mode: Bool = false,  completion: (((AVPlayer, Bool))-> Void)?) // (AVPplayer, loaded_from_cache)
    {
        self.full_screen_mode = full_screen_mode
        
        playersStorage.checkMemoryCapacity()
        
        VLLog.instance.printToConsole("players: " + String(describing: AGVideoLoader.getInstance.playersStorage.list.map({ $0.key.suffix(10) })))
        
        let cache = AGVideoCacheManager.getInstance
        
        if let cacheUrl = cache.checkCacheUrl(url: url) {
            
            VLLog.instance.printToConsole("\(self.full_screen_mode ? "F" : "") Загрузили из кэша - \(url.path.suffix(10))")
            
            let asset = AVAsset(url: cacheUrl)
            let currentItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: currentItem)
                
            DispatchQueue.main.async {
                completion?((player, true))
            }
            
            return
        }
        
        if let player = playersStorage.getPlayerBy(url_string: url.absoluteString) {

            VLLog.instance.printToConsole("\(self.full_screen_mode ? "F" : "") Загрузили из players - \(url.path.suffix(10))")

            DispatchQueue.main.async {
                completion?((player, false))
            }

            return
        }
        
        if file_lenghth == nil || file_lenghth! > noCachedFileSize {
            
            let asset = AVAsset(url: url)
            let currentItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: currentItem)
            VLLog.instance.printToConsole("\(self.full_screen_mode ? "F" : "") Загрузили в players - \(url.path.suffix(10))")
            self.playersStorage.put(url_string: url.absoluteString, player: player)
            
            DispatchQueue.main.async {
                completion?((player, false))
            }
            
            return
        }

        loadVideoCompletelyAtFirst(url: url, completion: completion)
    }
    
    private func loadVideoCompletelyAtFirst(url: URL, completion: (((AVPlayer, Bool))-> Void)?)
    {
        VLLog.instance.printToConsole("\(self.full_screen_mode ? "F" : "") Загружаем в кэш - \(url.path.suffix(10))")
        
        self.loaderDelegate = AGVideoResourceLoaderDelegate(withURL: url)
        
        if let loaderDelegate = self.loaderDelegate, let assetUrl = loaderDelegate.streamingAssetURL {
            let asset = AVURLAsset(url: assetUrl)
            
            asset.resourceLoader.setDelegate(loaderDelegate, queue: DispatchQueue.global())

            loaderDelegate.completion = { [weak self] data in
                if data != nil {
                    
                    let cache = AGVideoCacheManager()
                    
                    cache.store(data: data!, name: url.lastPathComponent) { [weak self] url in
                        
                        let asset = AVAsset(url: url)
                        let currentItem = AVPlayerItem(asset: asset)
                        let player = AVPlayer(playerItem: currentItem)
                        
                        DispatchQueue.main.async {
                            completion?((player, true))
                        }
                        
                        self?.playersStorage.removePlayer(for_url_string: url.absoluteString)
                    }
                } else {
                    self?.playersStorage.removePlayer(for_url_string: url.absoluteString)
                }
            }
            
            let currentItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: currentItem)
            self.playersStorage.put(url_string: url.absoluteString, player: player)
            
            DispatchQueue.main.async {
                completion?((player, false))
            }
        }
    }
    
    public func clearCache()
    {
        AGVideoCacheManager.getInstance.clearCache()
    }
    
    public func clearStorage()
    {
        playersStorage.clearStorage()
    }
    
    private func getMetadata(url: URL, completion: (([AVMetadataItem]?)->Void)?)
    {
        let asset = AVAsset(url: url)
        
        let key = "commonMetadata"
        
        asset.loadValuesAsynchronously(forKeys: [key]) { [weak asset] in
            var error: NSError? = nil
            switch asset?.statusOfValue(forKey: key, error: &error) {
            case .loaded:
                completion?(asset?.commonMetadata)
            case .failed:
                VLLog.instance.printToConsole("can get metadata - \(url.path.suffix(10))")
                break
            case .cancelled:
                VLLog.instance.printToConsole("can get metadata - \(url.path.suffix(10))")
                break
            default:
                VLLog.instance.printToConsole("can get metadata - \(url.path.suffix(10))")
                break
            }
        }
    }
    
    private func makeExport(url: URL)
    {
        let asset = AVAsset(url: url)

        let cacheUrl = AGVideoCacheManager.getInstance.getCacheNamePathURL(url: url)

        if asset.isExportable {

            let composition = AVMutableComposition()

            if let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)),
               let sourceVideoTrack = asset.tracks(withMediaType: .video).first {
                do {
                    try compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: sourceVideoTrack, at: CMTime.zero)
                } catch {
                    VLLog.instance.printToConsole("Failed to compose video file")
                    return
                }
            }
            if let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)),
               let sourceAudioTrack = asset.tracks(withMediaType: .audio).first {
                do {
                    try compositionAudioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: sourceAudioTrack, at: CMTime.zero)
                } catch {
                    VLLog.instance.printToConsole("Failed to compose audio file")
                    return
                }
            }

            let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)

            exporter?.outputURL = cacheUrl
            exporter?.outputFileType = AVFileType.mp4

            exporter?.exportAsynchronously(completionHandler: {
                switch exporter?.status {
                case .cancelled:
                    VLLog.instance.printToConsole("Exporter status - cancelled")
                    break
                case .completed:
                    VLLog.instance.printToConsole("Exporter status - completed")
                    break
                case .exporting:
                    VLLog.instance.printToConsole("Exporter status - exporting")
                    break
                case .failed:
                    VLLog.instance.printToConsole("Exporter status - failed")
                    break
                case .unknown:
                    VLLog.instance.printToConsole("Exporter status - unknown")
                    break
                case .waiting:
                    VLLog.instance.printToConsole("Exporter status - waiting")
                    break
                default:
                    VLLog.instance.printToConsole("Exporter status - default")
                }
                VLLog.instance.printToConsole("Cached!!  \(url.path.suffix(10))")
            })
        }
    }
}
