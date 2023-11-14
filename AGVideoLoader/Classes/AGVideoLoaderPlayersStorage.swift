//
//  AGVideoLoaderPlayersStorage.swift
//
//  Created by Aleksei Grebenkin on 20.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import AVFoundation

struct AGVideoLoaderPlayersStorage
{
    struct VLPlayer
    {
        var creation_timestamp:     Double
        var player:                 AVPlayer?
    }
    
    var maxMemoryCapacity: Int = 1024*1024*200 //200 MB
    var maxPlayersCountCapacity: Int = 10
    
    var list: [String: VLPlayer] = [String: VLPlayer]()
    
    mutating func put(url_string: String, player: AVPlayer? = nil)
    {
        var vl_player: VLPlayer
        
        if list.keys.contains(url_string) {
            list[url_string]!.creation_timestamp = NSDate().timeIntervalSince1970
            list[url_string]!.player = player
        } else {
            vl_player = VLPlayer(
                creation_timestamp: NSDate().timeIntervalSince1970,
                player: player
            )
            list[url_string] = vl_player
        }
    }
    
    mutating func removeEarlierPlayer()
    {
        let earlierPlayer = list.max(by: { (a, b) in
            return a.value.creation_timestamp > b.value.creation_timestamp
        })
        
        if let key = earlierPlayer?.key {
            list.removeValue(forKey: key)
        }
    }
    
    mutating func removePlayer(for_url_string: String)
    {
        list[for_url_string]?.player?.pause()
        
        list.removeValue(forKey: for_url_string)
    }
    
    mutating func checkMemoryCapacity()
    {
        if list.count > maxPlayersCountCapacity {
            VLLog.instance.printToConsole("Remove eirlier player")
            removeEarlierPlayer()
        }
    }
    
    mutating func clearStorage()
    {
        VLLog.instance.printToConsole("Clear players storage at all")
        list = [String: VLPlayer]()
    }
    
    func getPlayerBy(url_string: String) -> AVPlayer?
    {
        return list[url_string]?.player
    }
}
