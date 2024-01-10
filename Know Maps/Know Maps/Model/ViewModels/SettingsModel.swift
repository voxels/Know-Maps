//
//  SettingsModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import SwiftUI
import AuthenticationServices

open class SettingsModel : NSObject, ASAuthorizationControllerDelegate,  ObservableObject {
    public static let tag = "com.noisederived.Know-Maps.keys.appleuserid".data(using: .utf8)!

    @Published public var appleUserId:String
    @Published public var keychainId:String?
    @Published public var fullName:String?
    
    public init(userId: String, keychainId: String? = nil, fullName: String? = nil) {
        self.appleUserId = userId
        self.keychainId = keychainId
        self.fullName = fullName
    }
    
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            if appleUserId.isEmpty {
                appleUserId = appleIDCredential.user
            }
            fullName = "\(appleIDCredential.fullName?.givenName ?? "") \(appleIDCredential.fullName?.familyName ?? "")"
            print("Authorization successful for \(String(describing: fullName)).")
        }
    }
}
