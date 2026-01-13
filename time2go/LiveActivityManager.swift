import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    // 保存当前的 Activity 实例
    private var currentActivity: Activity<Time2GoAttributes>?
    
    func start(targetDate: Date, title: String, separator: String, icon: String = "timer", mode: String) {
        
        // 1. 检查权限
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let now = Date()
        let duration = targetDate.timeIntervalSince(now)
        
        // 容错：如果时间已过，不启动
        guard duration > 0 else { return }
        
        let attributes = Time2GoAttributes(mode: mode)
        let contentState = Time2GoAttributes.ContentState(
            targetDate: targetDate,
            timerName: title,
            iconName: icon,
            separator: separator,
            startDate: now,
            totalDuration: duration,
            isDone: false
        )
        
        do {
            // 🟢 2. 先创建新的 Activity (先上车)
            let newActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = newActivity
            print("🚀 Live Activity Started: \(newActivity.id)")
            
            // 🟢 3. 后补票：清理旧活动，但给新活动“免死金牌”
            Task {
                for activity in Activity<Time2GoAttributes>.activities {
                    // ⚠️ 关键判断：只有 ID 不一样的才杀掉
                    if activity.id != newActivity.id {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        print("🗑️ Cleaning up old activity: \(activity.id)")
                    }
                }
            }
            
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// 🔴 强行杀死（点击取消按钮时用）
    func stop() {
        Task {
            for activity in Activity<Time2GoAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self.currentActivity = nil
            print("🛑 All Live Activities Stopped")
        }
    }
    
    /// 🟢 优雅结束（倒计时自然归零时用）
    func finish() {
        guard let activity = currentActivity else { return }
        let old = activity.content.state
        
        // 创建“已完成”的状态
        let doneState = Time2GoAttributes.ContentState(
            targetDate: old.targetDate,
            timerName: old.timerName,
            iconName: old.iconName,
            separator: old.separator,
            startDate: old.startDate,
            totalDuration: old.totalDuration,
            isDone: true // 标记为结束
        )
        
        Task {
            // 1. 更新 UI 为完成态
            await activity.update(.init(state: doneState, staleDate: nil))
            
            // 2. 宣告结束，但保留在屏幕上 (.default)
            await activity.end(.init(state: doneState, staleDate: nil), dismissalPolicy: .default)
            
            self.currentActivity = nil
            print("✅ Live Activity Finished (Done State)")
        }
    }
    
    func update(targetDate: Date, title: String) {
        guard let activity = currentActivity else { return }
        let old = activity.content.state
        let newDuration = targetDate.timeIntervalSince(old.startDate)
        
        let newState = Time2GoAttributes.ContentState(
            targetDate: targetDate,
            timerName: title,
            iconName: old.iconName,
            separator: old.separator,
            startDate: old.startDate,
            totalDuration: newDuration,
            isDone: false
        )
        
        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }
    
    // 🟢🟢🟢 新增：强制刷新方法 🟢🟢🟢
    // 当在 App 内切换语言/主题时调用，强制 Live Activity 重绘 UI 以读取新设置
    func refresh() {
        guard let activity = currentActivity else { return }
        let state = activity.content.state
        Task {
            // 用当前状态 Update 一次，触发 View 重绘
            await activity.update(.init(state: state, staleDate: nil))
            print("🔄 Live Activity Refreshed (Theme/Language Sync)")
        }
    }
}
