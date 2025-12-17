//
//  ConfiguredSearchSession.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/21/25.
//

import Foundation

public struct ConfiguredSearchSession {
    static var shared = ConfiguredSearchSession.session()
    
    static func session()->URLSession {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 15   // Idle timeout between bytes
        sessionConfiguration.timeoutIntervalForResource = 30  // Overall resource timeout
        sessionConfiguration.waitsForConnectivity = false     // Don’t wait minutes for connectivity
        let session = URLSession(configuration: sessionConfiguration)
        return session
    }
}
