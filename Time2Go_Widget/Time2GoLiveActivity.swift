import ActivityKit
import WidgetKit
import SwiftUI

struct Time2GoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Time2GoAttributes.self) { context in
            // ===========================
            // 📱 锁屏界面 / 通知中心 UI
            // ===========================
            LockScreenView(context: context)
            
        } dynamicIsland: { context in
            // ===========================
            // 🏝️ 灵动岛 UI
            // ===========================
            let isExpired = Date() >= context.state.targetDate
            let shouldShowDone = context.state.isDone || isExpired
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    if shouldShowDone {
                        if context.attributes.mode == "countdown" {
                            Text("countdown.finished").font(.headline).foregroundStyle(.white)
                        } else {
                            Text(context.state.timerName).font(.headline).foregroundStyle(.white)
                        }
                    } else {
                        EmptyView()
                    }
                }
                DynamicIslandExpandedRegion(.leading) {
                    if !shouldShowDone {
                        HStack(spacing: 4) {
                            Image(systemName: context.state.iconName ?? "timer")
                                .foregroundStyle(.white).font(.body)
                        }.padding(.leading, 8)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !shouldShowDone {
                        Text(timerInterval: Date()...context.state.targetDate, countsDown: true)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.trailing, 8)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !shouldShowDone {
                        ProgressView(timerInterval: Date()...context.state.targetDate, countsDown: true)
                            .tint(.white).padding(.horizontal, 12).padding(.bottom, 8)
                    }
                }
            } compactLeading: {
                if shouldShowDone {
                    Image(systemName: "checkmark").foregroundStyle(.white)
                } else {
                    Image(systemName: context.state.iconName ?? "timer").foregroundStyle(.white)
                }
            } compactTrailing: {
                if shouldShowDone {
                    Text("Done").font(.caption).foregroundStyle(.white)
                } else {
                    Text(timerInterval: Date()...context.state.targetDate, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 40)
                        .foregroundStyle(.white)
                }
            } minimal: {
                Image(systemName: shouldShowDone ? "checkmark" : "timer").foregroundStyle(.white)
            }
        }
    }
}

// ===========================
// 🎨 锁屏视图 (已修复语言同步 + 纯黑底)
// ===========================
struct LockScreenView: View {
    let context: ActivityViewContext<Time2GoAttributes>
    @Environment(\.colorScheme) var systemScheme
    
    // 🟢 1. 使用 AppConfig，确保和 SettingsView 一致
    let appGroupID = "group.com.appetizer.Time2Go"
    
    var isDark: Bool {
        let defaults = UserDefaults(suiteName: appGroupID)
        let theme = defaults?.string(forKey: "appTheme") ?? "system"
        
        switch theme {
        case "dark": return true
        case "light": return false // 强制浅色，背景变白
        default: return systemScheme == .dark
        }
    }
    
    // 🟢 2. 读取语言设置 (之前你漏了这个)
    var selectedLocale: Locale {
        let defaults = UserDefaults(suiteName: appGroupID)
        let lang = defaults?.string(forKey: "appLanguage") ?? Locale.current.identifier
        return Locale(identifier: lang)
    }
    
    var body: some View {
        // 颜色修正：纯黑 (Pure Black)
        let backgroundColor = isDark ? Color.black : Color.white
        let primaryColor    = isDark ? Color.white : Color.black
        let iconColor       = isDark ? Color.white : Color.black
        
        let isExpired = Date() >= context.state.targetDate
        let shouldShowDone = context.state.isDone || isExpired
        
        ZStack {
            backgroundColor
            
            if shouldShowDone {
                // ✅ 完成态
                VStack {
                    if context.attributes.mode == "countdown" {
                        // "countdown.finished" 会随 environment 自动翻译
                        Text("countdown.finished")
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(primaryColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text(context.state.timerName)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(primaryColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            } else {
                // ⏳ 进行态
                VStack(spacing: 0) {
                    
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        
                        // 1. 图标
                        Image(systemName: context.state.iconName ?? "timer")
                            .font(.system(.title3))
                            .foregroundStyle(iconColor)
                            .padding(.trailing, 8)
                            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 4 }
                        
                        // 2. 标题
                        Text(context.state.timerName)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(primaryColor)
                            .minimumScaleFactor(1)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 3. 弹簧
                        Spacer(minLength: 8)
                        
                        // 4. 倒计时
                        Text(timerInterval: Date()...context.state.targetDate, countsDown: true)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(primaryColor)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    
                    // 进度条
                    ProgressView(
                        timerInterval: Date()...context.state.targetDate,
                        countsDown: true,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .tint(primaryColor)
                    .labelsHidden()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .activityBackgroundTint(backgroundColor)
        .activitySystemActionForegroundColor(primaryColor)
        // 🟢 3. 注入语言环境 (关键！没有这行，切换语言不会生效)
        .environment(\.locale, selectedLocale)
    }
}
