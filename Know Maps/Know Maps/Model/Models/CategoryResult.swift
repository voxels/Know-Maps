//
//  CategoryResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/22/23.
//

import Foundation

public struct CategoryResult : Identifiable, Equatable, Hashable {
    public static func == (lhs: CategoryResult, rhs: CategoryResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id = UUID()
    let parentCategory:String
    private(set) var categoricalChatResults:[ChatResult]
    
    mutating func replaceChatResults(with results:[ChatResult]) {
        categoricalChatResults = results
    }
    
    func result(for id:ChatResult.ID)->ChatResult? {
        return categoricalChatResults.filter { result in
            result.id == id || result.parentId == id
        }.first
    }
    
    func result(title:String)->ChatResult? {
        return categoricalChatResults.filter { result in
            result.title.lowercased().contains(title.lowercased().trimmingCharacters(in: .whitespaces)) || title.lowercased().contains(result.title.lowercased())
        }.first
    }
}
