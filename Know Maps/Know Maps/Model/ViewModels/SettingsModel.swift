//
//  SettingsModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import SwiftUI
import AuthenticationServices
import RevenueCat

open class SettingsModel : NSObject, ASAuthorizationControllerDelegate,  ObservableObject {
    public static let tag = "com.noisederived.Know-Maps.keys.appleuserid".data(using: .utf8)!

    @Published public var appleUserId:String
    @Published public var keychainId:String?
    @Published public var fullName:String?
    public var offerings:Offerings?
    public var purchasesId:String? {
        get {
#if os(iOS) || os(visionOS)
            return UIDevice.current.identifierForVendor?.uuidString
#endif

#if os(macOS)
            return keychainId
            #endif
        }
    }
    
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
    
    public func fetchSubscriptionOfferings(){
        Purchases.shared.getOfferings { [weak self] offerings, error in
            if let e = error{
                print(e)
            }
            if let offerings = offerings {
                self?.offerings = offerings
            }
        }
    }
}
