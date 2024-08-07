//
//  AssistiveChatHostDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/16/23.
//

import Foundation
import CoreLocation
import Segment

public protocol AssistiveChatHostDelegate:AnyObject {
    
    var messagesDelegate:AssistiveChatHostMessagesDelegate? { get set}
    var languageDelegate:LanguageGeneratorDelegate { get }
    var placeSearchSession:PlaceSearchSession { get }
    var queryIntentParameters:AssistiveChatHostQueryParameters? { get }
    var categoryCodes:[[String:[[String:String]]]] { get }
    var lastGeocodedPlacemarks:[CLPlacemark]? { get }
    var cloudCache:CloudCache { get }
    
    init(messagesDelegate: AssistiveChatHostMessagesDelegate?, analytics: Analytics?, lastGeocodedPlacemarks: [CLPlacemark]?)
    func organizeCategoryCodeList() throws
    func didTap(chatResult: ChatResult) async
    func didTap(categoricalResult:CategoryResult, chatResult:ChatResult?) async
    func determineIntent(for caption:String) -> AssistiveChatHost.Intent
    func updateLastIntentParameters(intent:AssistiveChatHostIntent)
    func appendIntentParameters(intent:AssistiveChatHostIntent)
    func resetIntentParameters()
    func receiveMessage(caption:String, isLocalParticipant:Bool ) async throws
    func defaultParameters(for query:String) async throws -> [String:Any]?
    func lastLocationIntent()->AssistiveChatHostIntent?
    func nearLocation(for rawQuery:String, tags:AssistiveChatHostTaggedWord?) async throws -> String?
    func nearLocationCoordinate(for rawQuery:String, tags:AssistiveChatHostTaggedWord?) async throws -> [CLPlacemark]?
    func tags(for rawQuery:String) throws ->AssistiveChatHostTaggedWord?
}
