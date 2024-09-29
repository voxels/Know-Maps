//
//  CategoryResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/22/23.
//

import Foundation

@Observable
public class CategoryResult : Identifiable, Equatable, Hashable {
    public static func == (lhs: CategoryResult, rhs: CategoryResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public let id = UUID()
    var parentCategory:String
    var list:String?
    var section:PersonalizedSearchSection?
    private(set) var categoricalChatResults:[ChatResult] = [ChatResult]()
    public var children:[CategoryResult] = [CategoryResult]()
    public var isExpanded:Bool = false
    
    public init(parentCategory: String, list:String? = nil, categoricalChatResults: [ChatResult], section:PersonalizedSearchSection? = nil) {
        self.parentCategory = parentCategory
        self.list = list
        self.categoricalChatResults = categoricalChatResults
        self.children = children(with: self.categoricalChatResults)
        self.section = section
    }
    
    func replaceChatResults(with results:[ChatResult]) {
        categoricalChatResults = results
        children = children(with: results)
    }
    
    func children(with chatResults:[ChatResult]?)->[CategoryResult] {
        var retval = [CategoryResult]()
        guard let chatResults = chatResults else {
            return retval
        }
        for chatResult in chatResults {
            if chatResult.title != parentCategory {
                let newCategoryResult = CategoryResult(parentCategory: chatResult.title, categoricalChatResults: [chatResult])
                retval.append(newCategoryResult)
            }
        }
        return retval
    }
    
    func result(for id:ChatResult.ID)->ChatResult? {
        return categoricalChatResults.filter { result in
            result.id == id || result.parentId == id
        }.first
    }
    
    func result(title:String)->ChatResult? {
        return categoricalChatResults.filter { result in
            result.title.lowercased() == title.lowercased().trimmingCharacters(in: .whitespaces)
        }.first
    }
}
