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
    
    public let id:String
    let  identity:String
    let parentCategory:String
    let list:String
    let icon:String
    let rating:Double
    let section:PersonalizedSearchSection
    private let categoricalChatResults:[ChatResult]
    private let children:[CategoryResult]
    public let isExpanded:Bool = false
    
    public init(identity:String, parentCategory: String,  list:String, icon:String, rating:Double, section:PersonalizedSearchSection, categoricalChatResults: [ChatResult]) {
        self.id = identity
        self.identity = identity
        self.parentCategory = parentCategory
        self.list = list
        self.icon = icon
        self.section = section
        self.categoricalChatResults = categoricalChatResults
        self.rating = rating
        self.children = CategoryResult.children(with: self.categoricalChatResults, parentCategory: parentCategory)
    }
    
    static func children(with chatResults:[ChatResult]?, parentCategory:String)->[CategoryResult] {
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

// Assuming CategoryResult looks something like this:
// struct CategoryResult {
//     let parentCategory: String
//     let rating: Double
//     // ...
// }

extension CategoryResult: RecommendationCategoryConvertible {
    public var recommenderIdentity: String {
        // Same behavior as your existing code: identity == parentCategory
        parentCategory
    }

    public var recommenderAttribute: String {
        // Also the same: attribute == parentCategory
        parentCategory
    }

    public var recommenderRating: Double {
        rating
    }
}
