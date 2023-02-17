//
//  AGCacheProviderConfig.swift
//
//  Created by  Aleksei Grebenkin on 13.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation

public struct AGCacheProviderConfig
{
    var cacheDirectoryName: String = "AGCache"
    /// MB
    var maxCacheDirectorySpace: Int = 300 * 1024 * 1024
}
