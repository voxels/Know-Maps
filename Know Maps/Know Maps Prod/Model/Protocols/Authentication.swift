//
//  AuthenticationService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import AuthenticationServices
import RevenueCat

// Define the protocol for authentication services
public protocol Authentication {
    var isAuthorized: Bool { get }
    var appleUserId: String { get set }
    var fullName: String? { get set }
    var authCompletion: ((Result<ASAuthorization, Error>) -> Void)? { get set }
    var offerings: Offerings? { get set }
    var purchasesId: String? { get }

    // Method to handle authorization completion
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization)

    // Retrieve the user ID from keychain
    func retrieveUserID() -> String?

    // Store the user ID in keychain
    func storeUserIDInKeychain(_ userID: String)

    // Fetch subscription offerings
    func fetchSubscriptionOfferings()

    // Retrieve user ID from keychain
    func retrieveUserIDFromKeychain() -> String?
}
