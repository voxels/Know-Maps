//
//  AssistiveChatHostQueryParameters.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/28/23.
//

import Foundation

open class AssistiveChatHostQueryParameters : ObservableObject, Equatable {
    public let uuid = UUID()
    public var queryIntents = [AssistiveChatHostIntent]()
    
    public static func == (lhs: AssistiveChatHostQueryParameters, rhs: AssistiveChatHostQueryParameters) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
