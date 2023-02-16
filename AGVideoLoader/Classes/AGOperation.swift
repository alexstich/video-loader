//
//  AGOperation.swift
//
//  Created by  Aleksei Grebenkin on 13.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation
import AVFoundation

final internal class AGOperation: Operation
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
        
        asset_.loadValuesAsynchronously(forKeys: AGVideoLoader.assetKeysRequiredToPlay) { [weak self] in
                        
            guard let self = self else { return }
            
            for key in AGVideoLoader.assetKeysRequiredToPlay {
                
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
