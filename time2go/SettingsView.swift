import SwiftUI
import Combine
import UIKit
import WidgetKit

private enum SettingsRoute: Hashable {
    case about
    case preferences
}

struct SettingsView: View {
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    
    // App Theme 还是只存 Group 即可，因为 App 也会读取 Group (如果 RootView 配置了的话)
    // 但为了保险，建议 Theme 也保持同步，不过这里先只修 Language
    @AppStorage("appTheme", store: UserDefaults(suiteName: AppConfig.appGroup))
    private var appThemeRaw: String = AppTheme.system.rawValue
    
    // 这里的 Wrapper 绑定的是 App Group
    @AppStorage("appLanguage", store: UserDefaults(suiteName: AppConfig.appGroup))
    private var appLanguageRaw: String = "en"

    @Binding var path: NavigationPath
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(l10n.t("tab.settings"))
                        .font(.system(size: 32, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 70)
                        .padding(.leading, 45)
                        .padding(.bottom, 40)

                    SettingsSectionCard {
                        NavigationLink(value: SettingsRoute.about) {
                            SettingsRow(icon: "info.circle", title: l10n.t("settings.about"))
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        NavigationLink(value: SettingsRoute.preferences) {
                            SettingsRow(icon: "slider.horizontal.3", title: l10n.t("settings.preferences"))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 80)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .about: AboutView()
                case .preferences: PreferencesView()
                }
            }
        }
        .onAppear {
            // 同步一次，防止不同步
            if let shared = UserDefaults(suiteName: AppConfig.appGroup) {
                // 如果 App Group 里有值，同步给 Standard，防止 App 没变
                let groupLang = shared.string(forKey: "appLanguage") ?? "en"
                if UserDefaults.standard.string(forKey: "appLanguage") != groupLang {
                    UserDefaults.standard.set(groupLang, forKey: "appLanguage")
                }
            }
        }
    }
}

// MARK: - AboutView
struct AboutView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (Build \(build))"
    }
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionCard { AboutValueRow(title: l10n.t("settings.version"), value: appVersionText) }
                .padding(.top, 25)
                Text(l10n.t("settings.follow_me")).font(.caption).foregroundColor(.secondary).padding(.leading, 40).padding(.top, 25)
                SettingsSectionCard {
                    Button { if let url = URL(string: "https://example.com") { UIApplication.shared.open(url) } } label: { SettingsRow(icon: "link", title: l10n.t("settings.follow_rednote")) }.buttonStyle(.plain)
                }
                SettingsSectionCard {
                    Button { if let url = URL(string: "mailto:help.appetizer@gmail.com") { UIApplication.shared.open(url) } } label: { SettingsRow(icon: "exclamationmark.bubble", title: l10n.t("settings.report")) }.buttonStyle(.plain)
                }
                .padding(.top, 30).padding(.bottom, 10)
                
                VStack(spacing: 30) {
                    VStack(spacing: -10) {
                        Image("Time2Go").resizable().scaledToFit().frame(width: 80, height: 80)
                        Text(l10n.t("settings.made_in")).font(.caption).foregroundStyle(.secondary)
                    }
                    VStack {
                        Image("Appetizer").resizable().scaledToFit().frame(width: 50, height: 50)
                        Text(l10n.t("settings.copyright")).font(.caption2).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(.top, 110).padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(l10n.t("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - PreferencesView (核心修改在这里)
struct PreferencesView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    
    @AppStorage("appTheme", store: UserDefaults(suiteName: AppConfig.appGroup))
    private var appThemeRaw: String = AppTheme.system.rawValue
    
    @AppStorage("appLanguage", store: UserDefaults(suiteName: AppConfig.appGroup))
    private var appLanguageRaw: String = "en"

    private var currentTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .system }
    private var isEnglish: Bool { appLanguageRaw == "en" }
    private var isChinese: Bool { appLanguageRaw == "zh-Hans" }
    private var isChineseTraditional: Bool { appLanguageRaw == "zh-Hant" }
    private var isKorean: Bool { appLanguageRaw == "ko" }
    private var isJapanese: Bool { appLanguageRaw == "ja" }
    
    // 🟢🟢🟢 修复逻辑：同时通知 Widget 和 App 🟢🟢🟢
    private func forceSaveLanguage(_ lang: String) {
        // 1. 更新当前视图状态 (App Group)
        appLanguageRaw = lang
        
        // 2. 显式写入 App Group (给 Widget 用)
        if let shared = UserDefaults(suiteName: AppConfig.appGroup) {
            shared.set(lang, forKey: "appLanguage")
            shared.synchronize()
        }
        
        // 3. 🟢 显式写入 Standard UserDefaults (给 App 自身用)
        // 你的 LocalizationManager 极有可能是在监听这个默认位置！
        UserDefaults.standard.set(lang, forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        
        // 4. 刷新 Widget
        WidgetCenter.shared.reloadAllTimelines()
        
        print("🔥 Language synced: \(lang) (AppGroup + Standard)")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("").padding(.top, 1)
                Text(l10n.t("preferences.language"))
                    .font(.subheadline.weight(.semibold)).foregroundColor(.secondary).padding(.leading, 40)

                SettingsSectionCard {
                    ThemeOptionRow(title: l10n.t("preferences.language_en"), isSelected: isEnglish) { forceSaveLanguage("en") }
                    SettingsDivider()
                    ThemeOptionRow(title: l10n.t("preferences.language_zh"), isSelected: isChinese) { forceSaveLanguage("zh-Hans") }
                    SettingsDivider()
                    ThemeOptionRow(title: l10n.t("preferences.language_zh_hant"), isSelected: isChineseTraditional) { forceSaveLanguage("zh-Hant") }
                    SettingsDivider()
                    ThemeOptionRow(title: l10n.t("preferences.language_ko"), isSelected: isKorean) { forceSaveLanguage("ko") }
                    SettingsDivider()
                    ThemeOptionRow(title: l10n.t("preferences.language_ja"), isSelected: isJapanese) { forceSaveLanguage("ja") }
                }
                .padding(.bottom, 25)

                Text(l10n.t("preferences.appearance"))
                    .font(.subheadline.weight(.semibold)).foregroundColor(.secondary).padding(.leading, 40)

                SettingsSectionCard {
                    ThemeOptionRow(title: l10n.t("preferences.system"), isSelected: currentTheme == .system) { appThemeRaw = AppTheme.system.rawValue }
                    SettingsDivider()
                    ThemeOptionRow(title: l10n.t("preferences.light"), isSelected: currentTheme == .light) { appThemeRaw = AppTheme.light.rawValue }
                    SettingsDivider()
                    ThemeOptionRow(title: l10n.t("preferences.dark"), isSelected: currentTheme == .dark) { appThemeRaw = AppTheme.dark.rawValue }
                }
                .padding(.bottom, 25)

                SettingsSectionCard {
                    SettingsToggleRow(icon: "iphone", title: l10n.t("preferences.keep_on"), subtitle: l10n.t("preferences.keep_on_sub"), isOn: $keepScreenOn)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, 80)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // 绑定 ID 强制刷新界面
        .id(appLanguageRaw)
    }
}

// MARK: - Helper Views (保持不变)
struct SettingsSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(UIColor.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(borderColor, lineWidth: 0.4))
            .padding(.horizontal, 30)
    }
    private var borderColor: Color { colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04) }
}

struct SettingsRow: View {
    let icon: String; let title: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 28, height: 28).foregroundColor(.primary)
            Text(title).font(.system(size: 17))
            Spacer(); Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(UIColor.tertiaryLabel))
        }.padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }
}

struct AboutValueRow: View {
    let title: String; let value: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "number").font(.system(size: 20)).frame(width: 28, height: 28).foregroundColor(.primary)
            Text(title).font(.system(size: 17)); Spacer()
            Text(value).font(.system(size: 17)).foregroundColor(.secondary)
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct SettingsToggleRow: View {
    let icon: String; let title: String; var subtitle: String? = nil; @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 28, height: 28).foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17))
                if let subtitle { Text(subtitle).font(.footnote).foregroundColor(.secondary) }
            }
            Spacer(); Toggle("", isOn: $isOn).labelsHidden()
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct ThemeOptionRow: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 17)); Spacer()
                if isSelected { Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.accentColor) }
            }.padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct SettingsDivider: View {
    var body: some View { Rectangle().fill(Color(UIColor.separator).opacity(0.4)).frame(height: 0.5).padding(.leading, 60) }
}

enum AppTheme: String, CaseIterable { case system, light, dark }

#Preview {
    SettingsView(path: .constant(NavigationPath()))
        .environmentObject(LocalizationManager())
}
