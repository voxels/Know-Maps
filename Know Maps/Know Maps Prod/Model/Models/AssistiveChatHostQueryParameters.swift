//
//  AssistiveChatHostQueryParameters.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/28/23.
//

import Foundation
import Combine

@Observable
public final class AssistiveChatHostQueryParameters : ObservableObject, Equatable, Sendable {
    public let uuid = UUID()
    public var queryIntents = [AssistiveChatHostIntent]()
    
    public static func == (lhs: AssistiveChatHostQueryParameters, rhs: AssistiveChatHostQueryParameters) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
