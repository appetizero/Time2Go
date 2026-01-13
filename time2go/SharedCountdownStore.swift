import Foundation
import WidgetKit

struct CountdownState: Codable {
    let mode: String
    let targetDate: Date?
    let isRunning: Bool
    let title: String
    let separator: String
    // 🆕 新增：标记任务是否处于“已完成但未确认”的状态
    var isFinished: Bool = false
}

struct SharedCountdownStore {
    private static let suiteName = AppConfig.appGroup
    private static let userDefaults = UserDefaults(suiteName: suiteName)
    private enum Keys { static let state = "shared_countdown_state" }

    // 🆕 修改 save 方法，增加 isFinished 参数
    static func save(mode: String, targetDate: Date?, isRunning: Bool, title: String, separator: String, isFinished: Bool = false) {
        let state = CountdownState(
            mode: mode,
            targetDate: targetDate,
            isRunning: isRunning,
            title: title,
            separator: separator,
            isFinished: isFinished // 保存状态
        )
        
        if let data = try? JSONEncoder().encode(state) {
            userDefaults?.set(data, forKey: Keys.state)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func load() -> CountdownState {
        guard let data = userDefaults?.data(forKey: Keys.state),
              let state = try? JSONDecoder().decode(CountdownState.self, from: data) else {
            return CountdownState(mode: "time2go", targetDate: nil, isRunning: false, title: "", separator: "", isFinished: false)
        }
        return state
    }
    
    static func clear() {
        // 清除所有状态
        save(mode: "time2go", targetDate: nil, isRunning: false, title: "", separator: "", isFinished: false)
    }
}
