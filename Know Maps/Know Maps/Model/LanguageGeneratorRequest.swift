//
//  LanguageGeneratorRequest.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 4/3/23.
//

import Foundation

public struct LanguageGeneratorRequest {
    let chatResult:ChatResult
    let model:String
    let prompt:String
    let maxTokens:Int
    let temperature:Float
    let stop:String?
    let user:String?
}
