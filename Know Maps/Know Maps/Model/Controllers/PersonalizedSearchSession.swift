//
//  PersonalizedSearchSession.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/10/24.
//

import Foundation
import CloudKit

public enum PersonalizedSearchSessionError : Error {
    case UnsupportedRequest
    case ServerErrorMessage
    case NoUserFound
    case NoTokenFound
    case NoTasteFound
}

open class PersonalizedSearchSession {
    public let cloudCache:CloudCache
    public var fsqIdentity:String?
    public var fsqAccessToken:String?
    private var fsqServiceAPIKey:String?
    let keysContainer = CKContainer(identifier:"iCloud.com.noisederived.No-Maps.Keys")
    private var searchSession:URLSession?
    static let serverUrl = "https://api.foursquare.com/"
    static let userManagementAPIUrl = "v2/usermanagement"
    static let userManagementCreationPath = "/createuser"
    static let tasteSuggestionsAPIUrl = "v2/tastes/suggestions"
    static let foursquareVersionDate = "20240101"
    
    public init(cloudCache: CloudCache, searchSession:URLSession? = nil) {
        self.cloudCache = cloudCache
        self.searchSession = searchSession
    }
}

extension PersonalizedSearchSession {
    @discardableResult
    public func fetchManagedUserIdentity() async throws ->String? {
        var cloudFsqIdentity = try await cloudCache.fetchFsqIdentity()
        if cloudFsqIdentity.isEmpty, cloudCache.hasPrivateCloudAccess {
            try await addFoursquareManagedUserIdentity()
            cloudFsqIdentity = try await cloudCache.fetchFsqIdentity()
        }
        
        guard !cloudFsqIdentity.isEmpty else {
            return nil
        }
        
        fsqIdentity = cloudFsqIdentity
        
        return fsqIdentity
    }
    
    @discardableResult
    public func fetchManagedUserAccessToken() async throws ->String {
        guard cloudCache.hasPrivateCloudAccess else {
            return ""
        }
        
        if fsqIdentity == nil, cloudCache.hasPrivateCloudAccess {
            try await fetchManagedUserIdentity()
        }
        
        guard let fsqIdentity = fsqIdentity, !fsqIdentity.isEmpty else {
            throw PersonalizedSearchSessionError.NoUserFound
        }
        
        let cloudToken = try await cloudCache.fetchToken(for: fsqIdentity)
        fsqAccessToken = cloudToken
        
        guard let token = fsqAccessToken, !token.isEmpty else {
            throw PersonalizedSearchSessionError.NoTokenFound
        }
        
        return token
    }
    
    @discardableResult
    private func addFoursquareManagedUserIdentity() async throws -> Bool {
        let apiKey = try await fetchFoursquareServiceAPIKey()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        guard let apiKey = apiKey, searchSession != nil else {
            return false
        }
        
        let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.userManagementAPIUrl)\(PersonalizedSearchSession.userManagementCreationPath)")
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let userCreationResponse = try await fetch(url: url, apiKey: apiKey, httpMethod: "POST")
        
        guard let response = userCreationResponse as? [String:Any] else {
            return false
        }
                        
        print(response)
        
        var identity:String? = nil
        var token:String? = nil
        
        if let responseDict = response["response"] as? NSDictionary {
            if let userId = responseDict["user_id"] as? Int {
                identity = "\(userId)"
            }
            if let accessToken = responseDict["access_token"] as? String {
                token = accessToken
            }
        }
        
        guard let identity = identity, let token = token else {
            throw PersonalizedSearchSessionError.NoUserFound
        }
        
        cloudCache.storeFoursquareIdentityAndToken(for: identity, oauthToken: token)
        
        return true
    }
}

extension PersonalizedSearchSession {
    public func fetchTastes(page:Int) async throws -> [String] {
        let apiKey = try await fetchManagedUserAccessToken()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        guard !apiKey.isEmpty, searchSession != nil else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.tasteSuggestionsAPIUrl)")
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let intentQueryItem = URLQueryItem(name: "intent", value: "tipstream")
        let limitQueryItem = URLQueryItem(name: "limit", value: "50")
        let offsetQueryItem = URLQueryItem(name: "offset", value:"\(page)")
        let response = try await fetch(url: url, apiKey: apiKey, urlQueryItems: [intentQueryItem, limitQueryItem, offsetQueryItem])
        
        guard let response = response as? [String:Any] else {
            throw PersonalizedSearchSessionError.NoTasteFound
        }
                        
        var retval = [String]()
        if let responseDict = response["response"] as? NSDictionary {
            if let tastesArray = responseDict["tastes"] as? [NSDictionary] {
                for taste in tastesArray {
                    if let text = taste["text"] as? String {
                        retval.append(text)
                    }
                }
            }
        }

        return retval
    }
}

extension PersonalizedSearchSession {
    private func fetchFoursquareServiceAPIKey() async throws -> String? {
        let task = Task.init { () -> Bool in
            let predicate = NSPredicate(format: "service == %@", "foursquareService")
            let query = CKQuery(recordType: "KeyString", predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["value", "service"]
            operation.resultsLimit = 1
            operation.recordMatchedBlock = { [weak self] recordId, result in
                guard let strongSelf = self else { return }

                do {
                    let record = try result.get()
                    if let apiKey = record["value"] as? String {
                        print("\(String(describing: record["service"]))")
                        strongSelf.fsqServiceAPIKey = apiKey
                    } else {
                        print("Did not find API Key")
                    }
                } catch {
                    print(error)
                }
            }
            
            let success = try await withCheckedThrowingContinuation { checkedContinuation in
                operation.queryResultBlock = { result in
                    if self.fsqServiceAPIKey == nil {
                        checkedContinuation.resume(with: .success(false))
                    } else if let apiKey = self.fsqServiceAPIKey, !apiKey.isEmpty {
                        checkedContinuation.resume(with: .success(true))
                    } else {
                        checkedContinuation.resume(with: .success(false))
                    }
                }
                
                keysContainer.publicCloudDatabase.add(operation)
            }
            
            return success
        }
        
        
        let _ = try await task.value
        return fsqServiceAPIKey
    }
}


extension PersonalizedSearchSession {
    internal func fetch(url:URL, apiKey:String, urlQueryItems:[URLQueryItem]? = nil, httpMethod:String = "GET") async throws -> Any {
        print("Requesting URL: \(url)")
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        let urlQueryItem = URLQueryItem(name: "v", value: PersonalizedSearchSession.foursquareVersionDate)
        var allQueryItems = [urlQueryItem]
        
        if let urlQueryItems = urlQueryItems {
            allQueryItems.append(contentsOf: urlQueryItems)
        }
        urlComponents?.queryItems = allQueryItems
        
        guard let queryUrl = urlComponents?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }

        var request = URLRequest(url:queryUrl)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = httpMethod
        
        let responseAny:Any = try await withCheckedThrowingContinuation({checkedContinuation in
            let dataTask = searchSession?.dataTask(with: request, completionHandler: { data, response, error in
                if let e = error {
                    print(e)
                    checkedContinuation.resume(throwing:e)
                } else {
                    if let d = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                            if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message.hasPrefix("Foursquare servers")  {
                                print("Message from server:")
                                print(message)
                                checkedContinuation.resume(throwing: PersonalizedSearchSessionError.ServerErrorMessage)
                            } else {
                                checkedContinuation.resume(returning:json)
                            }
                        } catch {
                            print(error)
                            let returnedString = String(data: d, encoding: String.Encoding.utf8) ?? ""
                            print(returnedString)
                            checkedContinuation.resume(throwing: PersonalizedSearchSessionError.ServerErrorMessage)
                        }
                    }
                }
            })
            
            dataTask?.resume()
        })
        
        return responseAny
    }
}
