import SwiftUI
import Combine
import UIKit
import WidgetKit
import ActivityKit

private enum CountdownPhase {
    case setting
    case running
    case paused
}

struct CountdownTimerView: View {

    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    @State private var phase: CountdownPhase = .setting
    @State private var remaining: Int = 0
    @State private var totalDuration: Int = 0

    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.colorScheme) private var colorScheme
    @State private var hasSelectionFlag: Bool = false
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    
    @State private var showOneThingAlert = false
    
    @EnvironmentObject private var l10n: LocalizationManager
    
    @Environment(\.scenePhase) private var scenePhase
    
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn && phase == .running
    }

    private var totalSelectedSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private var hasSelection: Bool {
        totalSelectedSeconds > 0
    }

    @ViewBuilder
    private var headerView: some View {
        if phase == .setting {
            headerSection
        }
    }

    @ViewBuilder
    private var centerView: some View {
        if phase == .setting {
            pickerSection
        } else {
            runningCenterSection
        }
    }

    @ViewBuilder
    private var bottomView: some View {
        if phase == .setting {
            settingBottomSection
        } else {
            runningBottomSection
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                // 🟢 修改：从 8 改为 10，与 ContentView 保持一致
                Spacer(minLength: 10)

                centerView

                Spacer(minLength: 8)

                bottomView
                    // 🟢 修改：从 15 改为 10，与 ContentView 保持一致
                    .padding(.bottom, 10)
            }
        }
        .onChange(of: hours) { _, _ in updateHasSelection() }
        .onChange(of: minutes) { _, _ in updateHasSelection() }
        .onChange(of: seconds) { _, _ in updateHasSelection() }
        .alert(l10n.t("time2go.alert_one_at_a_time"), isPresented: $showOneThingAlert) {
            Button(l10n.t("time2go.ok"), role: .cancel) { }
        }
        
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App 回到前台，检查共享数据，重新校准剩余时间
                let state = SharedCountdownStore.load()
                if state.isRunning && state.mode == "countdown", let target = state.targetDate {
                    let now = Date()
                    if target > now {
                        // 1. 如果还没结束，更新剩余时间
                        let diff = Int(target.timeIntervalSince(now))
                        self.remaining = diff
                        // 确保状态正确
                        if self.phase != .running { self.phase = .running }
                    } else {
                        // 2. 如果已经结束了，重置界面
                        self.remaining = 0
                        self.phase = .setting
                        SharedCountdownStore.clear() // 顺便清理一下
                        LiveActivityManager.shared.stop()
                    }
                } else if self.phase == .running {
                    // 3. 如果本地在跑，但共享状态说没跑（可能被 Widget 清除了），则停止
                    self.phase = .setting
                    self.remaining = 0
                }
            }
        }

        .onAppear {
            NotificationManager.shared.requestAuthorization()
            // 🆕 ✅ 新增：检查是否有正在进行的“倒计时”任务并恢复
            let state = SharedCountdownStore.load()
            if state.isRunning && state.mode == "countdown", let target = state.targetDate {
                let now = Date()
                if target > now {
                    // 1. 恢复运行
                    let diff = Int(target.timeIntervalSince(now))
                    self.remaining = diff
                    // 虽然丢失了原始 totalDuration，但为了 UI 显示正常，暂时设为剩余时间即可
                    self.totalDuration = diff
                    self.phase = .running
                } else {
                    // 2. 已过期，清理 Widget
                    SharedCountdownStore.clear()
                    WidgetCenter.shared.reloadAllTimelines()
                    self.phase = .setting
                }
            }
            updateHasSelection()
            updateIdleTimer()
        }
        .onChange(of: phase) { _, _ in
            updateIdleTimer()
        }
        .onChange(of: keepScreenOn) { _, _ in
            updateIdleTimer()
        }
        .onReceive(ticker) { _ in
            guard phase == .running else { return }
                    
            if remaining <= 0 {
                remaining = 0
                phase = .setting
                        
                // 倒计时结束，清除 Widget
                SharedCountdownStore.clear()
                WidgetCenter.shared.reloadAllTimelines()
                        
                // 🟢🟢🟢 改动：调用 finish 而不是 stop 🟢🟢🟢
                LiveActivityManager.shared.finish() // 👈 让它变成完成态
                return
            }

            remaining -= 1
        }
        .alert(l10n.t("time2go.alert_one_at_a_time"), isPresented: $showOneThingAlert) {
            Button(l10n.t("time2go.ok"), role: .cancel) { }
        }
    }

    private var headerSection: some View {

        Text(l10n.t("tab.countdown"))
            .font(.system(size: 32, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
            .padding(.horizontal, 24)
            .multilineTextAlignment(.center)
    }

    private var pickerSection: some View {
        VStack(spacing: 40) {
            HStack(spacing: 0) {
                wheelColumn(value: $hours, range: 0..<24, unit: "hours")
                wheelColumn(value: $minutes, range: 0..<60, unit: "min")
                wheelColumn(value: $seconds, range: 0..<60, unit: "sec")
            }
            .frame(height: 200)
            .clipped()
            .padding(.horizontal, 26)
        }
    }

    private var settingBottomSection: some View {
        VStack(spacing: 20) {
            
            Text(durationDescription(totalSelectedSeconds))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .center)

            Divider()
                .padding(.horizontal, 45)
                .opacity(0.3)

            VStack(spacing: 20) {
                PrimaryButton(
                
                    title: l10n.t("time2go.reset"),
                    icon: "arrow.counterclockwise",
                    isEnabled: hasSelectionFlag,
                    action: {
                        resetSelection()
                    }
                )

                PrimaryButton(
                    
                    title: l10n.t("time2go.start"),
                    isEnabled: hasSelectionFlag,
                    action: {
                        if SharedCountdownStore.load().isRunning {
                            showOneThingAlert = true
                            return
                        }
                        
                        withAnimation(.none) {
                            startTimer()
                        }
                    }
                )
            }
            .padding(.horizontal, 50)
            .animation(nil, value: hasSelectionFlag)
            .padding(.bottom, 28)
        }
    }

    private var runningCenterSection: some View {
        VStack(spacing: 10) {
            Text(formattedTime(remaining))
                .font(.system(size: 50,
                              weight: .medium,
                              design: .monospaced))
                .minimumScaleFactor(0.6)
        }
    }

    private var runningBottomSection: some View {
        VStack(spacing: 20) {
            
            Divider()
                .padding(.horizontal, 45)
                .opacity(0.3)

            VStack(spacing: 20) {
                Group {
                    if phase == .paused {
                        PrimaryButton(
                            title: l10n.t("countdown.resume"),
                            icon: "play.fill",
                            isEnabled: true,
                            action: {
                                phase = .running
                            }
                        )
                    } else {
                        PrimaryButton(
                            title: l10n.t("countdown.pause"),
                            icon: "pause.fill",
                            isEnabled: true,
                            action: {
                                phase = .paused
                            }
                        )
                    }
                }
                .padding(.horizontal, 50)
                .transaction { $0.animation = nil }

                PrimaryButton(
                    title: l10n.t("time2go.cancel"),
                    isEnabled: true,
                    action: {
                        resetSelection()
                    }
                )
                .padding(.horizontal, 50)
            }
            .transaction { $0.animation = nil }
            .padding(.bottom, 28)
        }
    }

    private func wheelColumn(value: Binding<Int>, range: Range<Int>, unit: String) -> some View {
        GeometryReader { geo in

            let w = geo.size.width

            let numberArea = w * 0.52
            let unitArea   = w - numberArea

            ZStack {
                Picker("", selection: value) {
                    ForEach(Array(range), id: \.self) { number in
                        
                        HStack(spacing: 12) {
                            Text("\(number)")
                                .font(.system(size: 20))
                                .frame(width: numberArea, alignment: .trailing)

                            Color.clear
                                .frame(width: unitArea)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: numberArea)

                    Text(displayUnit(for: value.wrappedValue, baseUnit: unit))
                        .font(.system(size: 20))
                        .foregroundColor(Color(.label))
                        .frame(width: unitArea, alignment: .leading)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
    }


    private func displayUnit(for value: Int, baseUnit: String) -> String {
        switch baseUnit {
        case "hours":
            
            return value == 1
                ? l10n.t("countdown.unit.hour_singular")
                : l10n.t("countdown.unit.hour_plural")
        case "min":
            return l10n.t("countdown.unit.minute")
        case "sec":
            return l10n.t("countdown.unit.second")
        default:
            return baseUnit
        }
    }

    private func updateHasSelection() {
        hasSelectionFlag = (hours != 0 || minutes != 0 || seconds != 0)
    }

    private func resetSelection() {
        // 🟢 1. 界面状态归零 (这是之前漏掉的关键！)
        hours = 0
        minutes = 0
        seconds = 0
        
        remaining = 0
        totalDuration = 0
        phase = .setting
        hasSelectionFlag = false
            
        // 🟢 2. 外部状态清理 (通知、Widget、灵动岛)
        SharedCountdownStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.stop()
        NotificationManager.shared.cancelAllNotifications()
    }
    
    private func startTimer() {
        totalDuration = totalSelectedSeconds
        remaining = totalSelectedSeconds
        phase = .running
                
        // 1️⃣ 第一步：先计算结束时间 (必须在前面！)
        let endDate = Date().addingTimeInterval(TimeInterval(totalSelectedSeconds))
            
        // 2️⃣ 第二步：保存到 SharedCountdownStore (原有代码)
        SharedCountdownStore.save(
            mode: "countdown",
            targetDate: endDate,
            isRunning: true,
            title: l10n.t("tab.countdown"),
            separator: l10n.t("time2go.in")
        )
        
        NotificationManager.shared.scheduleNotification(
            at: endDate,
            title: l10n.t("tab.countdown"),
            body: l10n.t("notification.countdown_finished")
        )
        
        // 3️⃣ 第三步：启动 Live Activity (必须在 endDate 定义之后！)
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            LiveActivityManager.shared.start(
                targetDate: endDate, // 👈 这里用到了上面的 endDate
                title: l10n.t("tab.countdown"),
                separator: l10n.t("time2go.in"),
                icon: "hourglass",
                mode: "countdown"
            )
        }
    }

    private func togglePause() {
        if phase == .running { phase = .paused }
        else if phase == .paused { phase = .running }
    }

    private func formattedTime(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        return h > 0
            ? String(format: "%02d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private func durationDescription(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60

        let hSuffix = l10n.t("countdown.suffix.h")
        let mSuffix = l10n.t("countdown.suffix.m")
        let sSuffix = l10n.t("countdown.suffix.s")

        if h > 0 && m > 0 && s > 0 {
            return "\(h)\(hSuffix) \(m)\(mSuffix) \(s)\(sSuffix)"
        }
        if h > 0 && m > 0 {
            return "\(h)\(hSuffix) \(m)\(mSuffix)"
        }
        if h > 0 {
            return "\(h)\(hSuffix)"
        }
        if m > 0 && s > 0 {
            return "\(m)\(mSuffix) \(s)\(sSuffix)"
        }
        if m > 0 {
            return "\(m)\(mSuffix)"
        }
        if s > 0 {
            return "\(s)\(sSuffix)"
        }

        return l10n.t("countdown.less_than_one_second")
    }
}

#Preview("Light") {
    CountdownTimerView()
        .environmentObject(LocalizationManager())
        .preferredColorScheme(.light)
}
