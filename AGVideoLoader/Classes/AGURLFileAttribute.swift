//
//  AGURLFileAttribute.swift
//
//  Created by  Aleksei Grebenkin on 13.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation

internal struct AGURLFileAttribute {
    
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
        let attributes = AGURLFileAttribute(url: self)
        return attributes.fileSize ?? 0
    }
    
    public func creationDate() -> Date? {
        let attributes = AGURLFileAttribute(url: self)
        return attributes.creationDate
    }
}
