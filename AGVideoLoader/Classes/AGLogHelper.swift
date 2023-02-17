//
//  AGLogHelper.swift
//
//  Created by  Aleksei Grebenkin on 13.02.2023.
//  Copyright © 2023 dimfcompany. All rights reserved.
//

import Foundation

final internal class AGLogHelper
{
    static let instance = AGLogHelper()
    static var debugModeOn: Bool = false
    
    private init(){}
    
    func printToConsole(_ str: String)
    {
        if AGLogHelper.debugModeOn {
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current// Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "HH:mm:ss"
            dateFormatter.timeZone = .current
            let dateString = dateFormatter.string(from: Date())
            
            print(dateString + " 🐙 AG *** " + str)
        }
    }
}
