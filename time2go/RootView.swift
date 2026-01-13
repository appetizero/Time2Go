import SwiftUI
import WidgetKit // 👈 1. 引入 WidgetKit

struct RootView: View {
    @State private var selectedTab: AppTab = .timer
    @State private var isOverlayActive: Bool = false

    // ⚠️ 2. 定义共享的 UserDefaults (必须和 SharedCountdownStore 里的一样)
    static let sharedDefaults = UserDefaults(suiteName: AppConfig.appGroup)

    // ⚠️ 3. 修改这里的 store 参数，让它存到共享区域
    @AppStorage("appTheme", store: RootView.sharedDefaults)
    private var appThemeRaw: String = AppTheme.system.rawValue
    
    @State private var settingsPath = NavigationPath()

    @EnvironmentObject private var l10n: LocalizationManager

    private var appColorScheme: ColorScheme? {
        guard let theme = AppTheme(rawValue: appThemeRaw) else { return nil }
        switch theme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // ... 你的 Tab 内容保持不变 ...
            ContentView(isOverlayActive: $isOverlayActive)
                .tabItem { Label(l10n.t("tab.time2go"), systemImage: AppTab.timer.icon) }
                .tag(AppTab.timer)

            CountdownTimerView()
                .tabItem { Label(l10n.t("tab.countdown"), systemImage: AppTab.stats.icon) }
                .tag(AppTab.stats)

            SettingsView(path: $settingsPath)
                .tabItem { Label(l10n.t("tab.settings"), systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .settings {
                settingsPath = NavigationPath()
            }
        }
        // ✅ 4. 新增：当主题改变时，强制刷新 Widget
        .onChange(of: appThemeRaw) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .preferredColorScheme(appColorScheme)
    }
}

#Preview("Root with Tabs") {
    RootView()
        .environmentObject(LocalizationManager())
}
