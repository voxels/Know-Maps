//
//  FollowUp.swift
//  Runner
//
//  Created by Joni-Pekka Vesto on 26.11.2024.
//


struct FollowUp {
    let id: Int
    let content: String
}

extension FollowUp: CustomStringConvertible {
    var description: String {
        return "FollowUp(id: \(id), content: \"\(content)\")"
    }
}
