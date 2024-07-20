//
//  Item.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 08.07.2024.
//

import Foundation
import SwiftData

@Model
final class Goal {
    @Attribute(.unique)
    var creationDate: Date
    var title: String
    var isCompleted: Bool
    
    init(title: String, isCompleted: Bool, priority: Int = 0) {
        self.creationDate = Date()
        self.title = title
        self.isCompleted = isCompleted
    }
}
