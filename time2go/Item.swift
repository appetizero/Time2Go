//
//  Item.swift
//  time2go
//
//  Created by appetizimo on 2025-12-01.
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
