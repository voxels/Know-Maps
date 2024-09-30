//
//  SettingsModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import SwiftUI
import AuthenticationServices
import RevenueCat
import Security

public enum SettingsModelError : Error {
    case failed
}

open class SettingsModel : NSObject, ASAuthorizationControllerDelegate,  ObservableObject {
    public static let tag = "com.noisederived.Know-Maps.keys.appleuserid".data(using: .utf8)!

    public var isAuthorized:Bool {
        return retrieveUserID() != nil
    }
    
    public var appleUserId:String
    public var keychainId:String?
    public var fullName:String?
    public var authCompletion:((Result<ASAuthorization, Error>) -> Void)?
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
    
    public init(userId: String, keychainId: String? = nil, fullName: String? = nil ) {
        self.appleUserId = userId
        self.keychainId = keychainId
        self.fullName = fullName
    }
    
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            appleUserId = appleIDCredential.user
            storeUserIDInKeychain(appleUserId)
            fullName = "\(appleIDCredential.fullName?.givenName ?? "") \(appleIDCredential.fullName?.familyName ?? "")"
            print("Authorization successful for \(String(describing: fullName)).")
            authCompletion?(.success(authorization))
        } else {
            authCompletion?(.failure(SettingsModelError.failed))
        }
    }
    
    func retrieveUserID() -> String? {
        let userID = retrieveUserIDFromKeychain()
        if let userID = userID {
            appleUserId = userID
        }
        return userID
    }

    func storeUserIDInKeychain(_ userID: String) {
        let account = "userIdentifier"
        let service = Bundle.main.bundleIdentifier ?? "YourAppService"
        let data = Data(userID.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error storing userID in Keychain: \(status)")
        }
    }

    func retrieveUserIDFromKeychain() -> String? {
        let account = "userIdentifier"
        let service = Bundle.main.bundleIdentifier ?? "YourAppService"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data,
               let userID = String(data: data, encoding: .utf8) {
                return userID
            }
        } else {
            print("Error retrieving userID from Keychain: \(status)")
        }
        return nil
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
