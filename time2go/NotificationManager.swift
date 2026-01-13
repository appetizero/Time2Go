import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    override init() {
        super.init()
        // 设置代理，以便处理前台通知
        UNUserNotificationCenter.current().delegate = self
    }

    // 1. 申请权限
    func requestAuthorization() {
        // 🟢 新增 .timeSensitive 权限申请
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // 2. 安排通知
    func scheduleNotification(at date: Date, title: String, body: String) {
        cancelAllNotifications()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // 🟢 关键：设置为时效性通知 (Time Sensitive)
        // 这会让通知突破“摘要”和“专注模式”，系统也会认为它更重要
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "time2go_notification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("⏰ Notification scheduled for [\(title)] at \(date)")
            }
        }
    }

    // 3. 取消所有通知
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🗑️ All notifications cancelled")
    }
    
    // 🟢 4. 新增：App 在前台时也要弹出通知 (Banner)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 允许在前台播放声音和显示横幅
        completionHandler([.banner, .sound, .list])
    }
}
