import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), state: .init(mode: "time2go", targetDate: nil, isRunning: false, title: "", separator: "", isFinished: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let state = SharedCountdownStore.load()
        let entry = SimpleEntry(date: Date(), state: state)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let state = SharedCountdownStore.load()
        let entry = SimpleEntry(date: Date(), state: state)

        var policy: TimelineReloadPolicy
            
        // 如果正在运行且没过期，按结束时间刷新；否则稍微延后一点
        if state.isRunning, let targetDate = state.targetDate, targetDate > Date() {
            policy = .after(targetDate)
        } else {
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            policy = .after(nextUpdate)
        }
        
        let timeline = Timeline(entries: [entry], policy: policy)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let state: CountdownState
}

struct Time2GoWidgetEntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.colorScheme) var systemScheme

    var selectedScheme: ColorScheme {
        let defaults = UserDefaults(suiteName: AppConfig.appGroup)
        let theme = defaults?.string(forKey: "appTheme") ?? "system"
        
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return systemScheme
        }
    }
    
    var langCode: String {
        let defaults = UserDefaults(suiteName: AppConfig.appGroup)
        return defaults?.string(forKey: "appLanguage") ?? "en"
    }

    var body: some View {
        Group {
            // 🟢🟢🟢 核心逻辑修改 🟢🟢🟢
            // 判定为“进行中”或“完成态”
            let isRunning = entry.state.isRunning
            let isFinishedState = entry.state.isFinished
            // 自然过期（时间到了）
            let isExpired = (entry.state.targetDate != nil && Date() >= entry.state.targetDate!)
            
            // 如果明确标记了 finish，或者虽然还在 running 但时间已过 -> 显示完成态
            if isFinishedState || (isRunning && isExpired) {
                // === ✅ 完成态 (Done State) ===
                VStack(spacing: 6) {
                    if entry.state.mode == "countdown" {
                        Text("countdown.finished".forceLocalized(langCode))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    } else {
                        // Time2Go 模式：只显示 Title
                        Text(entry.state.title)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.5)
                    }
                }
            } else if isRunning, let targetDate = entry.state.targetDate {
                // === ⏳ 倒计时进行中 ===
                if entry.state.mode == "countdown" {
                    VStack {
                        Text(timerInterval: Date()...targetDate, countsDown: true)
                            .font(.system(size: 45, weight: .medium, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                    }
                } else {
                    VStack(spacing: 4) {
                        Text(entry.state.title)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                        
                        Text("time2go.in".forceLocalized(langCode))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text(timerInterval: Date()...targetDate, countsDown: true)
                            .font(.system(size: 40, weight: .medium, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                // === ⚪️ 空闲状态 (Idle) ===
                VStack(spacing: 6) {
                    Text("widget.empty_prompt".forceLocalized(langCode))
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .id(langCode)
        .environment(\.colorScheme, selectedScheme)
        .containerBackground(for: .widget) {
            if selectedScheme == .dark {
                Color.black
            } else {
                Color.white
            }
        }
    }
}

struct Time2GoWidget: Widget {
    let kind: String = "Time2GoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Time2GoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Time2Go")
        .description("看看什么时候Go。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension String {
    func forceLocalized(_ lang: String) -> String {
        var path = Bundle.main.path(forResource: lang, ofType: "lproj")
        if path == nil {
            let short = String(lang.prefix(2))
            path = Bundle.main.path(forResource: short, ofType: "lproj")
        }
        if path == nil && lang.contains("zh") {
             path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj")
        }
        if let safePath = path, let bundle = Bundle(path: safePath) {
            return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return self
    }
}
