import Foundation

public final class FoursquareCategoryMapper {
    private let categoryTaxonomy: [String: Any]
    
    public init() {
        if let path = Bundle.main.path(forResource: "integrated_category_taxonomy", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.categoryTaxonomy = json
        } else {
            self.categoryTaxonomy = [:]
        }
    }
    
    /// Finds the Foursquare category ID for a given label (e.g., "Sushi", "Coffee Shop").
    public func categoryID(for label: String) -> String? {
        let lowercaseLabel = label.lowercased()
        
        for (id, details) in categoryTaxonomy {
            if let detailsDict = details as? [String: Any],
               let labels = detailsDict["labels"] as? [String: String],
               let enLabel = labels["en"]?.lowercased() {
                
                if enLabel == lowercaseLabel {
                    return id
                }
            }
        }
        
        // Secondary check in full_label array if exact match fails
        for (id, details) in categoryTaxonomy {
            if let detailsDict = details as? [String: Any],
               let fullLabel = detailsDict["full_label"] as? [String] {
                if fullLabel.contains(where: { $0.lowercased() == lowercaseLabel }) {
                    return id
                }
            }
        }
        
        return nil
    }
    
    /// Maps a list of labels to their category IDs.
    public func categoryIDs(for labels: [String]) -> [String] {
        return labels.compactMap { categoryID(for: $0) }
    }
}
