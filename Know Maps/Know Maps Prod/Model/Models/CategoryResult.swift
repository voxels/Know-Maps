//
//  CategoryResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/22/23.
//

import Foundation

@Observable
public final class CategoryResult : Identifiable, Equatable, Hashable, Sendable {
    public static func == (lhs: CategoryResult, rhs: CategoryResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public let id = UUID()
    var identity:String
    var parentCategory:String
    var list:String
    var icon:String
    var rating:Double
    var section:PersonalizedSearchSection
    private(set) var categoricalChatResults:[ChatResult] = [ChatResult]()
    public var children:[CategoryResult] = [CategoryResult]()
    public var isExpanded:Bool = false
    
    public init(identity:String, parentCategory: String,  list:String, icon:String, rating:Double, section:PersonalizedSearchSection, categoricalChatResults: [ChatResult]) {
        self.identity = identity
        self.parentCategory = parentCategory
        self.list = list
        self.icon = icon
        self.section = section
        self.categoricalChatResults = categoricalChatResults
        self.section = section
        self.rating = rating
        self.children = children(with: self.categoricalChatResults)
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
                let newCategoryResult = CategoryResult(identity: chatResult.identity, parentCategory: chatResult.title, list:chatResult.list, icon: chatResult.icon, rating: chatResult.rating, section:chatResult.section, categoricalChatResults: [chatResult])
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
