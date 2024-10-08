import Foundation
import CloudKit

public enum LanguageGeneratorSessionError : Error {
    case ServiceNotFound
    case UnsupportedRequest
    case InvalidServerResponse
}

open class LanguageGeneratorSession : NSObject, ObservableObject {
    private var openaiApiKey = ""
    private var searchSession:URLSession?
    let keysContainer = CKContainer(identifier:"iCloud.com.secretatomics.knowmaps.Keys")
    static let serverUrl = "https://api.openai.com/v1/chat/completions"
        
    override init(){
        super.init()
    }
    
    init(apiKey: String = "", session: URLSession? = nil) {
        self.openaiApiKey = apiKey
        self.searchSession = session
        if let containerIdentifier = keysContainer.containerIdentifier {
            print(containerIdentifier)
        }
    }
    
    public func query(languageGeneratorRequest:LanguageGeneratorRequest, delegate:AssistiveChatHostStreamResponseDelegate? = nil) async throws->NSDictionary? {
        if searchSession == nil {
            searchSession = try await session()
        }
        
        guard let searchSession = searchSession else {
            throw LanguageGeneratorSessionError.ServiceNotFound
        }
        
        let components = URLComponents(string: LanguageGeneratorSession.serverUrl)

        guard let url = components?.url else {
            throw LanguageGeneratorSessionError.ServiceNotFound
        }
        
        var request = URLRequest(url:url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(self.openaiApiKey)", forHTTPHeaderField: "Authorization")
        
        var body:[String : Any] = ["model":languageGeneratorRequest.model, "messages":[[String:String]]()]
        
        var messagesArray = [[String:String]]()
        messagesArray.append(["role":"system", "content":"You are a helpful assistant"])
        messagesArray.append(["role":"user", "content":languageGeneratorRequest.prompt])
        
        body["messages"] = messagesArray

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
                
        return try await fetch(urlRequest: request, apiKey: self.openaiApiKey, session:searchSession) as? NSDictionary
    }
    
    internal func fetch(urlRequest:URLRequest, apiKey:String, session:URLSession ) async throws -> Any {
        print("Requesting URL: \(String(describing: urlRequest.url))")
        let responseAny:Any = try await withCheckedThrowingContinuation({checkedContinuation in
            let dataTask = session.dataTask(with: urlRequest, completionHandler: { data, response, error in
                if let e = error {
                    print(e)
                    checkedContinuation.resume(throwing:e)
                } else {
                    if let d = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: d)
                            checkedContinuation.resume(returning:json)
                        } catch {
                            print(error)
                            let returnedString = String(data: d, encoding: String.Encoding.utf8)
                            print(returnedString ?? "")
                            checkedContinuation.resume(throwing:error)
                        }
                    }
                }
            })
            
            dataTask.resume()
        })
        
        return responseAny
    }
    
    internal func fetchBytes(urlRequest:URLRequest, apiKey:String, session:URLSession, languageGeneratorRequest:LanguageGeneratorRequest, delegate:AssistiveChatHostStreamResponseDelegate) async throws -> NSDictionary? {
        print("Requesting URL: \(String(describing: urlRequest.url))")
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LanguageGeneratorSessionError.InvalidServerResponse
        }
        
        let retVal = NSMutableDictionary()
        var fullString = ""

        for try await line in bytes.lines {
            if line == "data: [DONE]" {
                break
            }
            
            guard let d = line.dropFirst(5).data(using: .utf8) else {
                throw LanguageGeneratorSessionError.InvalidServerResponse
            }
            guard let json = try JSONSerialization.jsonObject(with: d) as? NSDictionary else {
                throw LanguageGeneratorSessionError.InvalidServerResponse
            }
            guard let choices = json["choices"] as? [NSDictionary] else {
                throw LanguageGeneratorSessionError.InvalidServerResponse
            }
            
            if let firstChoice = choices.first, let text = firstChoice["text"] as? String {
                fullString.append(text)
                await delegate.didReceiveStreamingResult(with: text, for:languageGeneratorRequest.chatResult, promptTokens: 0, completionTokens: 0)
            }
        }
        
        fullString = fullString.trimmingCharacters(in: .whitespaces)
        retVal["text"] = fullString
        return retVal
    }
        
    
    public func session() async throws -> URLSession {
        let task = Task.init { () -> Bool in
            let predicate = NSPredicate(format: "service == %@", "openai")
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
                        strongSelf.openaiApiKey = apiKey
                    } else {
                        print("Did not find API Key")
                    }
                } catch {
                    print(error)
                }
            }
            
            let success = try await withCheckedThrowingContinuation { checkedContinuation in
                operation.queryResultBlock = { result in
                    if self.openaiApiKey == "" {
                        checkedContinuation.resume(with: .success(false))
                    } else {
                        checkedContinuation.resume(with: .success(true))
                    }
                }
                
                keysContainer.publicCloudDatabase.add(operation)
            }
            
            return success
        }
        
        
        let foundApiKey = try await task.value
        if foundApiKey {
            return configuredSession( key: self.openaiApiKey)
        } else {
            throw LanguageGeneratorSessionError.ServiceNotFound
        }
    }
}

private extension LanguageGeneratorSession {
    func configuredSession(key:String)->URLSession {
        print("Beginning Language Generator Session with key \(key)")
        
        let sessionConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfiguration)
        return session
    }
}
