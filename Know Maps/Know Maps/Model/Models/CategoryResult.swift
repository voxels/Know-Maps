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
    let list:String?
    private(set) var categoricalChatResults:[ChatResult]?
    public var children:[CategoryResult]?
    
    public init(parentCategory: String, list:String? = nil, categoricalChatResults: [ChatResult]? = nil ) {
        self.parentCategory = parentCategory
        self.list = list
        self.categoricalChatResults = categoricalChatResults
        self.children = children(with: self.categoricalChatResults)
    }
    
    mutating func replaceChatResults(with results:[ChatResult]) {
        categoricalChatResults = results
        children = children(with: results)
    }
    
    func children(with chatResults:[ChatResult]?)->[CategoryResult]? {
        guard let chatResults = chatResults else {
            return nil
        }
        var retval = [CategoryResult]()
        for chatResult in chatResults {
            if chatResult.title != parentCategory {
                let newCategoryResult = CategoryResult(parentCategory: chatResult.title, categoricalChatResults: [chatResult])
                retval.append(newCategoryResult)
            }
        }
        return retval.isEmpty ? nil : retval
    }
    
    func result(for id:ChatResult.ID)->ChatResult? {
        return categoricalChatResults?.filter { result in
            result.id == id || result.parentId == id
        }.first
    }
    
    func result(title:String)->ChatResult? {
        return categoricalChatResults?.filter { result in
            result.title.lowercased() == title.lowercased().trimmingCharacters(in: .whitespaces)
        }.first
    }
}
