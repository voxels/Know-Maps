//
//  ChatDetailsViewModel.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 4/4/23.
//

import Foundation
import CoreLocation

public enum ChatDetailsViewModelError : Error {
    case NoIntentFound
}

public protocol ChatDetailsViewModelDelegate : AnyObject {
    func modelDidUpdate()
}

public class ChatDetailsViewModel {
    public var currentIntent:AssistiveChatHostIntent
    public var queryParameters:AssistiveChatHostQueryParameters
    public var responseString:String?
    public var placeSearchResponses:[PlaceSearchResponse] = [PlaceSearchResponse]()
    public var placeDetailsResponses:[PlaceDetailsResponse] = [PlaceDetailsResponse]()
    public weak var delegate:ChatDetailsViewModelDelegate?
    internal var maxChatResults = 20
    
    private var placeSearchSession = PlaceSearchSession()
    
    public init(queryParameters:AssistiveChatHostQueryParameters, intent:AssistiveChatHostIntent, delegate:ChatDetailsViewModelDelegate? ) {
        self.currentIntent = intent
        self.queryParameters = queryParameters
        self.delegate = delegate
    }
    
    public func updateModel(parameters:AssistiveChatHostQueryParameters, responseString:String? = nil, placeSearchResponses:[PlaceSearchResponse] = [PlaceSearchResponse](), placeDetailsResponses:[PlaceDetailsResponse]?) async throws {
        guard let lastIntent = parameters.queryIntents.last else {
            throw ChatDetailsViewModelError.NoIntentFound
        }
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.currentIntent = lastIntent
            strongSelf.queryParameters = parameters
            strongSelf.responseString = responseString
            strongSelf.placeSearchResponses = placeSearchResponses
            strongSelf.placeDetailsResponses = placeDetailsResponses ?? [PlaceDetailsResponse]()
        
            strongSelf.delegate?.modelDidUpdate()
        }
    }
    
    public func updateModelResponse(_ string:String) {
        responseString = string
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.modelDidUpdate()
        }
    }
}
