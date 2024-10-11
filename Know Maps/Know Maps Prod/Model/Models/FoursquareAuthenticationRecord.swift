//
//  FoursquareAuthenticationRecord.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/10/24.
//

import Foundation
import SwiftData

public final class FoursquareAuthenticationRecord  {
    public var fsqid: String = ""
    public var fsqUserId: String = ""
    public var oauthToken: String = ""
    public var serviceAPIKey: String = ""
    
    public init(fsqid: String, fsqUserId: String, oauthToken: String, serviceAPIKey: String) {
        self.fsqid = fsqid
        self.fsqUserId = fsqUserId
        self.oauthToken = oauthToken
        self.serviceAPIKey = serviceAPIKey
    }
}
