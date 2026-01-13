import ActivityKit
import SwiftUI

struct Time2GoAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态数据
        var targetDate: Date
        var timerName: String
        var iconName: String?
        var separator: String
        
        var startDate: Date
        var totalDuration: TimeInterval
        
        // 🟢 新增：标记是否已结束
        var isDone: Bool = false
    }

    var mode: String
}
