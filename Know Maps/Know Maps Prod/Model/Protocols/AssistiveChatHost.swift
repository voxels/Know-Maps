//
//  AssistiveChatHostDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/16/23.
//

import Foundation
import CoreLocation
import Segment

public protocol AssistiveChatHost:AnyObject, Sendable{
    
    var messagesDelegate:AssistiveChatHostMessagesDelegate { get }
    var placeSearchSession:PlaceSearchSession { get }
    var queryIntentParameters:AssistiveChatHostQueryParameters { get }
    var categoryCodes:[[String:[[String:String]]]] { get }
    
    init(analyticsManager:AnalyticsService, messagesDelegate: AssistiveChatHostMessagesDelegate)
    
    func determineIntent(for caption:String, override:AssistiveChatHostService.Intent?) -> AssistiveChatHostService.Intent
    func updateLastIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async
    func appendIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async
    func resetIntentParameters()
    func receiveMessage(caption:String, isLocalParticipant:Bool, filters:[String:Any], cacheManager:CacheManager,modelController:ModelController ) async throws
    func defaultParameters(for query:String, filters:[String:Any]) async throws -> [String:Any]?
    func lastLocationIntent()->AssistiveChatHostIntent?
    func nearLocation(for rawQuery:String, tags:AssistiveChatHostTaggedWord?) async throws -> String?
    func nearLocationCoordinate(for rawQuery:String, tags:AssistiveChatHostTaggedWord?) async throws -> [CLPlacemark]?
    func tags(for rawQuery:String) throws ->AssistiveChatHostTaggedWord?
    func section(for title:String)->PersonalizedSearchSection
}
