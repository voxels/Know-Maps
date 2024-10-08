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
    var recordId:String
    var parentCategory:String
    var list:String
    var icon:String
    var rating:Int
    var section:PersonalizedSearchSection
    private(set) var categoricalChatResults:[ChatResult] = [ChatResult]()
    public var children:[CategoryResult] = [CategoryResult]()
    public var isExpanded:Bool = false
    
    public init(parentCategory: String, recordId:String, list:String, icon:String, rating:Int, section:PersonalizedSearchSection, categoricalChatResults: [ChatResult]) {
        self.parentCategory = parentCategory
        self.recordId = recordId
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
                let newCategoryResult = CategoryResult(parentCategory: chatResult.title, recordId:"", list:chatResult.list, icon: chatResult.icon, rating: chatResult.rating, section:chatResult.section, categoricalChatResults: [chatResult])
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
