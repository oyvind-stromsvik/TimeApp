//
//  Item.swift
//  Time
//
//  Created by Øyvind Strømsvik on 29/06/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
