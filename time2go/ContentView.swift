import SwiftUI
import Combine
import UIKit
import WidgetKit
import ActivityKit

enum TimePurpose: String, CaseIterable, Identifiable {
    case go, work, school, pickup, custom
    var id: String { rawValue }

    func titleKey() -> String {
        switch self {
        case .go:     return "purpose.go"
        case .work:   return "purpose.work"
        case .school: return "purpose.school"
        case .pickup: return "purpose.pickup"
        case .custom: return "purpose.custom"
        }
    }
}

struct ContentView: View {
    @Binding var isOverlayActive: Bool
    @State private var targetDate: Date = ContentView.nextMinute()
    @State private var isRunning: Bool = false
    @State private var isFinishedMode: Bool = false // 🆕 控制显示 Done 界面
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentTitle: String = ""
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @EnvironmentObject private var l10n: LocalizationManager

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn && isRunning
    }

    var body: some View {
        ZStack {
            if isFinishedMode {
                // ✅ 3. 完成态界面
                DoneView(title: currentTitle) {
                    // 点击 Checkmark 后的动作
                    isFinishedMode = false
                    isRunning = false
                    SharedCountdownStore.clear() // 🧹 只有这一步才会让 Widget 变回空闲
                    WidgetCenter.shared.reloadAllTimelines()
                    NotificationManager.shared.cancelAllNotifications()
                }
            } else if isRunning {
                // ⏳ 2. 倒计时界面
                CountdownScreen(
                    targetDate: targetDate,
                    title: currentTitle,
                    onCancel: {
                        isRunning = false
                        isFinishedMode = false
                        SharedCountdownStore.clear()
                        WidgetCenter.shared.reloadAllTimelines()
                        LiveActivityManager.shared.stop()
                        NotificationManager.shared.cancelAllNotifications()
                    },
                    onFinish: {
                        // 🟢 倒计时自然结束：
                        // 不清除 Widget，而是更新为“已完成”状态
                        isFinishedMode = true
                        SharedCountdownStore.save(
                            mode: "time2go",
                            targetDate: targetDate,
                            isRunning: false, // 停止运行
                            title: currentTitle,
                            separator: "",
                            isFinished: true // 标记为完成
                        )
                        LiveActivityManager.shared.finish() // 灵动岛变 Done
                    }
                )
            } else {
                // ⚙️ 1. 设置界面
                SetupScreen(
                    targetDate: $targetDate,
                    onStart: { title in
                        targetDate = max(targetDate, ContentView.nextMinute())
                        currentTitle = title
                        isRunning = true
                        isFinishedMode = false
                        
                        SharedCountdownStore.save(
                            mode: "time2go",
                            targetDate: targetDate,
                            isRunning: true,
                            title: title,
                            separator: l10n.t("time2go.in")
                        )
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        NotificationManager.shared.scheduleNotification(
                            at: targetDate,
                            title: title,
                            body: l10n.t("notification.time_is_up")
                        )
                        
                        if ActivityAuthorizationInfo().areActivitiesEnabled {
                            LiveActivityManager.shared.start(
                                targetDate: targetDate,
                                title: title,
                                separator: l10n.t("time2go.in"),
                                icon: "figure.walk",
                                mode: "time2go"
                            )
                        }
                    },
                    isOverlayActive: $isOverlayActive
                )
            }
        }
        .onAppear {
            updateIdleTimer()
            checkExternalState()
            NotificationManager.shared.requestAuthorization()
        }
        .onChange(of: isRunning) { _, _ in updateIdleTimer() }
        .onChange(of: keepScreenOn) { _, _ in updateIdleTimer() }
        
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkExternalState()
            }
        }
    }
    
    // 检查 Widget/Store 的状态，同步 UI
    private func checkExternalState() {
        let state = SharedCountdownStore.load()
        
        if state.isFinished {
            // 如果 Store 里标记完成了，App 也要显示完成页
            self.currentTitle = state.title
            self.isFinishedMode = true
            self.isRunning = false
        } else if state.isRunning && state.mode == "time2go", let target = state.targetDate {
            if target > Date() {
                // 还在跑
                self.targetDate = target
                self.currentTitle = state.title
                self.isRunning = true
                self.isFinishedMode = false
            } else {
                // 过期了但还没标记 finish (App 后台过期)，自动进入 finish
                self.currentTitle = state.title
                self.isFinishedMode = true
                self.isRunning = false
                
                // 补发 finish 状态
                SharedCountdownStore.save(mode: "time2go", targetDate: target, isRunning: false, title: state.title, separator: "", isFinished: true)
                LiveActivityManager.shared.finish()
            }
        } else {
            // 空闲
            if !self.isFinishedMode { // 防止刚点完成还没刷新的情况
                self.isRunning = false
            }
        }
    }
}

struct DoneView: View {
    let title: String
    let onConfirm: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false
    @State private var shimmerPhase: CGFloat = -0.5
    
    // 📐 尺寸常量
    private let trackHeight: CGFloat = 72 // 稍微调小一点高度，更精致
    private let padding: CGFloat = 4
    private var knobSize: CGFloat { trackHeight - (padding * 2) }
    
    var body: some View {
        VStack {
            // 1. 顶部弹簧：把 Title 往下推一点，但不要推太深
            Spacer()
            
            // 2. 大标题
            Text(title)
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            
            Spacer()
            
            // 4. 🛹 滑动条区域
            GeometryReader { geometry in
                let trackWidth = geometry.size.width
                let maxDrag = trackWidth - knobSize - (padding * 2)
                
                ZStack(alignment: .leading) {
                    
                    // 轨道背景
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // 流光文字
                    ZStack {
                        Text("slide.confirm")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.3))
                            .padding(.leading, 30)
                        
                        Text("slide.confirm")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .padding(.leading, 30)
                            .mask(
                                GeometryReader { maskGeo in
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.clear, .white, .clear]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 100)
                                        .offset(x: maskGeo.size.width * shimmerPhase)
                                }
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isCompleted ? 0 : (1 - Double(dragOffset / maxDrag)))
                    
                    // 滑块 (Knob)
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Color(UIColor.systemBackground))
                            .opacity(isCompleted ? 1 : 0.6)
                            .scaleEffect(isCompleted ? 1.1 : 1.0)
                    }
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: padding + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isCompleted {
                                    let translation = value.translation.width
                                    if translation > 0 && translation <= maxDrag {
                                        dragOffset = translation
                                    }
                                }
                            }
                            .onEnded { value in
                                if dragOffset > maxDrag * 0.65 {
                                    withAnimation(.bouncy(duration: 0.4)) {
                                        dragOffset = maxDrag
                                        isCompleted = true
                                    }
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onConfirm()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                }
                .onAppear {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        shimmerPhase = 1.5
                    }
                }
            }
            .frame(height: trackHeight)
            // 🟢 修改点：增加水平 Padding，让按钮变短 (之前是 30)
            .padding(.horizontal, 50)
            // 🟢 修改点：底部留白，不要贴底太近
            .padding(.bottom, 120)
        }
        .background(Color.black.opacity(0.001))
    }
}

extension ContentView {
    static func nextMinute(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let base = calendar.date(from: comps) ?? date
        if base <= date {
            return calendar.date(byAdding: .minute, value: 1, to: base) ?? date.addingTimeInterval(60)
        } else {
            return base
        }
    }
}

extension ContentView {
    struct SetupScreen: View {
        @Environment(\.colorScheme) private var colorScheme
        @EnvironmentObject private var l10n: LocalizationManager

        @Binding var targetDate: Date
        let onStart: (String) -> Void

        @Binding var isOverlayActive: Bool
        
        @FocusState private var isTitleFocused: Bool

        @State private var isDatePickerPresented: Bool = false
        @State private var showPurposeMenu = false

        @State private var tempSelectedDate: Date = Date()

        @AppStorage("timePurpose") private var purposeRaw: String = TimePurpose.go.rawValue
        
        // Custom 模式的存储
        @AppStorage("customSuffixEN") private var customSuffixEN: String = ""
        @AppStorage("customSuffixZH") private var customSuffixZH: String = ""
        
        // Pickup 模式的存储
        @AppStorage("pickupSuffixEN") private var pickupSuffixEN: String = ""
        @AppStorage("pickupSuffixZH") private var pickupSuffixZH: String = ""
        
        @State private var baselineSnapshot: Date = Date()

        @State private var followNow: Bool = true
        @State private var isAutoUpdating: Bool = false
        
        @State private var isUserInteractingWheel: Bool = false
        @State private var isPickingDate: Bool = false
        
        @State private var wheelIdleWorkItem: DispatchWorkItem?
        @State private var pendingSmoothWork: DispatchWorkItem?
        
        @State private var showLimitAlert = false
        
        @State private var showTitleLimitAlert = false
        
        // 🟢 辅助变量：判断当前是否是“输入模式”（Custom 或 Pickup）
        private var isInputMode: Bool {
            purpose == .custom || purpose == .pickup
        }
        
        // 🟢 修改：判断输入框是否为空（根据模式切换检查对象）
        private var isInputEmpty: Bool {
            if purpose == .pickup {
                return (isChinese ? pickupSuffixZH : pickupSuffixEN).isEmpty
            }
            return (isChinese ? customSuffixZH : customSuffixEN).isEmpty
        }
        
        // 🟢 修改：Binding 逻辑，根据模式读写不同的变量
        private var textBinding: Binding<String> {
            Binding(
                get: {
                    if purpose == .pickup { return isChinese ? pickupSuffixZH : pickupSuffixEN }
                    return isChinese ? customSuffixZH : customSuffixEN
                },
                set: { newValue in
                    let limit = 12
                    let finalValue = newValue.count > limit ? String(newValue.prefix(limit)) : newValue
                    
                    // 如果被截断了，触发弹窗
                    if newValue.count > limit { showTitleLimitAlert = true }

                    if purpose == .pickup {
                        if isChinese { pickupSuffixZH = finalValue }
                        else { pickupSuffixEN = finalValue }
                    } else {
                        if isChinese { customSuffixZH = finalValue }
                        else { customSuffixEN = finalValue }
                    }
                }
            )
        }
        
        private var dateRange: ClosedRange<Date> {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return start...end
        }
        
        private let nowTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        private var purpose: TimePurpose {
            TimePurpose(rawValue: purposeRaw) ?? .go
        }

        private var isChinese: Bool {
            l10n.locale.identifier.hasPrefix("zh")
        }

        // 🟢 修改：前缀逻辑
        private var fixedPrefix: String {
            // 1. Pickup 模式特殊处理
            if purpose == .pickup {
                if isChinese { return "该去接" }
                
                // 🟢 修改：韩语也保持 Time2 品牌前缀
                // 这样显示效果就是：Time2 [Name] ...
                if isKorean || isJapanese { return "Time2 " }
                
                // 英文：Time2Pick [Name] Up
                return "Time2Pick "
            }
            
            // 2. Custom 模式原有逻辑 (保持不变)
            let baseText = isChinese ? l10n.t("time2go.prefix.zh") : l10n.t("time2go.prefix.en")
            if isKorean || isJapanese { return "\(baseText)\u{2009}" }
            return baseText
        }

        // 🟢 修改：后缀逻辑
        private var fixedSuffixTail: String {
            if purpose == .pickup {
                if isChinese { return "啦" }
                
                // 🟢 修改：韩语后缀改为 " 픽업" (Pickup)
                // 组合起来就是：Time2 [Name] 픽업
                if isKorean { return " 픽업" }
                
                if isJapanese { return " お迎え" }
                    
                return " Up"
            }
            // Custom 模式 (保持不变)
            return isChinese ? l10n.t("time2go.tail.zh") : ""
        }

        // 🟢 修改：占位符/默认值逻辑
        private var effectiveXXX: String {
            if isInputMode { // 支持 Custom 和 Pickup
                let raw = textBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty { return raw }

                // 如果没填字，显示的默认灰字
                if purpose == .pickup {
                    return l10n.t("time2go.pickup_placeholder")
                }
                
                return isChinese
                ? l10n.t("time2go.custom_default_zh")
                : l10n.t("time2go.custom_default_en")
            } else {
                return l10n.t("time2go.xxx.\(purpose.rawValue)")
            }
        }

        // 🟢 修改：最终标题生成逻辑
        private var effectiveTitle: String {
            if isInputMode {
                // Custom: Time2 [Title] (zh: 啦)
                // Pickup: Time2Pick [Name] Up
                return "\(fixedPrefix)\(effectiveXXX)\(fixedSuffixTail)"
            } else {
                return l10n.t("time2go.purpose.\(purpose.rawValue)")
            }
        }

        private var dateFieldBackground: Color {
            colorScheme == .dark ? Color.white.opacity(0.08) : Color(white: 0.97)
        }

        private var dateFieldBorder: Color {
            colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.06)
        }

        private var isAtNowSelection: Bool {
            abs(targetDate.timeIntervalSince(ContentView.nextMinute())) < 0.5
        }

        private var canResetSelection: Bool {
            !isAutoUpdating && !isAtNowSelection
        }

        private var canStart: Bool {
            !isAtNowSelection && targetDate > ContentView.nextMinute()
        }

        private var timeRange: ClosedRange<Date> {
            let min = ContentView.nextMinute()
            let end = Calendar.current.date(byAdding: .day, value: 7, to: min)!
            return min...end
        }

        private var deltaText: String {
            let clampedTarget = max(targetDate, ContentView.nextMinute())
            return localizedDeltaText(from: Date(), to: clampedTarget)
        }

        private var formattedDateDisplay: String {
            let cal = Calendar.current
            // 使用 Key: time2go.today / tomorrow
            if cal.isDateInToday(targetDate) { return l10n.t("time2go.today") }
            if cal.isDateInTomorrow(targetDate) { return l10n.t("time2go.tomorrow") }

            let f = DateFormatter()
            let id = l10n.locale.identifier

            // 英文使用硬编码格式，中文/韩文等使用拼接格式
            if id.hasPrefix("en") {
                f.locale = l10n.locale
                f.dateFormat = "MMM d, yyyy"
                return f.string(from: targetDate)
            } else {
                return localizedDateYMD(targetDate)
            }
        }
        
        // 对应 Key: date.unit.year / month / day
        private func localizedDateYMD(_ date: Date) -> String {
            let cal = Calendar.current
            let y = cal.component(.year, from: date)
            let m = cal.component(.month, from: date)
            let d = cal.component(.day, from: date)

            let yUnit = l10n.t("date.unit.year")
            let mUnit = l10n.t("date.unit.month")
            let dUnit = l10n.t("date.unit.day")

            return "\(y)\(yUnit) \(m)\(mUnit) \(d)\(dUnit)"
        }

        // 对应 Key: time2go.delta_*
        private func localizedDeltaText(from start: Date, to end: Date) -> String {
            let seconds = Int(end.timeIntervalSince(start))
            if seconds <= 0 {
                return l10n.t("time2go.delta_less_than_one_minute")
            }

            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60

            if hours > 0 && minutes > 0 {
                return String(format: l10n.t("time2go.delta_h_m"), hours, minutes)
            } else if hours > 0 {
                return String(format: l10n.t("time2go.delta_h"), hours)
            } else if minutes > 0 {
                return String(format: l10n.t("time2go.delta_m"), minutes)
            } else {
                return l10n.t("time2go.delta_less_than_one_minute")
            }
        }

        private func setOverlayActiveNoAnim(_ value: Bool) {
            var t = Transaction()
            t.animation = nil
            withTransaction(t) {
                isOverlayActive = value
            }
        }

        private func dismissCalendar() {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDatePickerPresented = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                setOverlayActiveNoAnim(false)
            }
        }
        
        // 🟢 修改：完全分离 Custom 和 Pickup 的宽度逻辑
        private var inputMaxWidth: CGFloat {
                    
            switch purpose {
            case .pickup:
                // ===========================
                // 🚗 接人模式 (Pickup)
                // ===========================
                
                if isJapanese {
                    return 85
                }
                
                if !isChinese && !isKorean && !isJapanese {
                    // 🇺🇸 英文: 前缀 "Time2Pick " 很长，输入框必须窄，只能放名字
                    return 80
                }
                // 🇨🇳 🇰🇷 中文/韩文: 前缀短 ("Time2 " 或 "该去接")，可以用标准宽度
                return 90
                
            case .custom:
                // ===========================
                // ✏️ 自定义模式 (Custom)
                // ===========================
                
                if isJapanese {
                    return 190
                }
                
                if !isChinese && !isKorean {
                    // 🇺🇸 英文: 前缀 "Time2" 很短，且 Placeholder 是 "You Decide!"
                    // 需要很宽的空间才能显示全
                    return 175
                }
                // 🇨🇳 🇰🇷 中文/韩文: 标准宽度
                return 150
                
            default:
                // 其他模式 (其实用不到，但为了安全)
                return 200
            }
        }

        var body: some View {
            GeometryReader { geo in
                ZStack {
                    VStack(spacing: 0) {
                        headerSection
                        
                        Spacer(minLength: 10)
                        
                        pickerSection
                        Spacer(minLength: 8)
                        
                        bottomSection
                        // ✅ 保持原来的 10，不动布局
                        .padding(.bottom, 10)
                    }
                                
                    dateOverlay
                        .opacity(isDatePickerPresented ? 1 : 0)
                        .allowsHitTesting(isDatePickerPresented)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            .onChange(of: targetDate) { _, _ in
                guard !isPickingDate else { return }
                guard !isAutoUpdating else { return }
                followNow = false
                isUserInteractingWheel = true
                wheelIdleWorkItem?.cancel()
                let work = DispatchWorkItem { isUserInteractingWheel = false }
                wheelIdleWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
            .onAppear {
                let state = SharedCountdownStore.load()
                // 只有当模式匹配且正在运行时才恢复
                if state.isRunning && state.mode == "time2go", let target = state.targetDate {
                    if target > Date() {
                        // 1. 还没结束，恢复运行状态
                        self.targetDate = target
                        // 如果你保存了 title，也可以在这里恢复
                        onStart(state.title)
                    } else {
                        // 2. 已经过期了，顺手帮 Widget 清理一下
                        SharedCountdownStore.clear()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
            .onReceive(nowTicker) { now in
                guard followNow else { return }
                if isUserInteractingWheel {
                    pendingSmoothWork?.cancel()
                    pendingSmoothWork = nil
                    return
                }
                let nm = ContentView.nextMinute(from: now)
                if targetDate < nm {
                    pendingSmoothWork?.cancel()
                    pendingSmoothWork = nil
                    isAutoUpdating = true
                    targetDate = nm
                    baselineSnapshot = nm
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isAutoUpdating = false }
                    return
                }
                let remaining = nm.timeIntervalSince(now)
                if remaining <= 0 {
                    pendingSmoothWork?.cancel()
                    pendingSmoothWork = nil
                    return
                }
                if remaining <= 1.2 {
                    if pendingSmoothWork != nil { return }
                    let delay = max(0, remaining - 0.30)
                    let work = DispatchWorkItem {
                        guard followNow, !isUserInteractingWheel else { return }
                        guard !isAutoUpdating else { return }
                        isAutoUpdating = true
                        smoothAdvanceToNextMinute(expectedNextMinute: nm)
                    }
                    pendingSmoothWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
                } else {
                    pendingSmoothWork?.cancel()
                    pendingSmoothWork = nil
                }
            }
            .alert(l10n.t("time2go.alert_one_at_a_time"), isPresented: $showLimitAlert) {
                Button(l10n.t("time2go.ok"), role: .cancel) { }
            }
            .alert(l10n.t("time2go.title_limit_hint"), isPresented: $showTitleLimitAlert) {
                Button(l10n.t("time2go.ok"), role: .cancel) { }
            }
            // 🟢 ✅ Sheet 放在这里 (最最最下面)
            // 只要放在这里，点击背景蒙层一定能返回！
            .sheet(isPresented: $showPurposeMenu) {
                VStack(spacing: 0) {
                    // 顶部小把手
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    
                    ForEach(TimePurpose.allCases) { p in
                        Button {
                            // 1. 先退出键盘/焦点
                            isTitleFocused = false
                                
                            // 2. 切换模式
                            // 使用 Transaction 防止动画冲突
                            var tx = Transaction()
                            tx.animation = nil
                            tx.disablesAnimations = true
                            withTransaction(tx) {
                                purposeRaw = p.rawValue
                            }

                            // 3. 关闭弹窗
                            showPurposeMenu = false
                        } label: {
                            // 使用 ZStack 或 Overlay 来保证文字绝对居中
                            Text(l10n.t("time2go.\(p.titleKey())"))
                                .font(.headline)
                                .foregroundColor(.primary)
                                // ✅ 关键点 1: 占满宽度 + 居中对齐
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 16) // 增加垂直高度，让手指更容易点
                                // ✅ 关键点 2: 加上这个让整行空白区域都能被点击
                                .contentShape(Rectangle())
                                // (可选) 如果你想要保留对勾，且不影响文字居中，可以用 overlay
                                .overlay(alignment: .trailing) {
                                    if p == purpose {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .padding(.trailing, 25)
                                    }
                                }
                        }
                        .buttonStyle(.plain)

                        // 分割线
                        if p != TimePurpose.allCases.last {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }

                    Spacer()
                }
                // ✅ 关键点 3: 限制弹窗高度，去掉多余的空白
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.hidden)
            }
        }
        
        private func smoothAdvanceToNextMinute(expectedNextMinute: Date) {
            let calendar = Calendar.current
            let now = Date()
            guard let endOfCurrentMinute = calendar.date(
                bySettingHour: calendar.component(.hour, from: now),
                minute: calendar.component(.minute, from: now),
                second: 59,
                of: now
            ) else {
                targetDate = expectedNextMinute
                baselineSnapshot = expectedNextMinute
                isAutoUpdating = false
                return
            }
            withAnimation(.linear(duration: 0.18)) { targetDate = endOfCurrentMinute }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.linear(duration: 0.22)) { targetDate = expectedNextMinute }
                baselineSnapshot = expectedNextMinute
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) { isAutoUpdating = false }
            }
        }

        private var isKorean: Bool { l10n.locale.identifier.hasPrefix("ko") }
        private var isJapanese: Bool { l10n.locale.identifier.hasPrefix("ja") }
        private var isEnglish: Bool { l10n.locale.identifier.hasPrefix("en") }

        private var customHeaderFontSize: CGFloat {
            if isChinese { return 30 }
            if isKorean { return 28 }
            if isEnglish { return 25 }
            return 30
        }
        
        private var headerTopPadding: CGFloat {
            return 70
        }

        private var headerSection: some View {
            VStack(spacing: 10) {

                // 🟢 关键修改：Custom 和 Pickup 都进入输入模式
                if isInputMode {

                    // ===========================
                    // 🅰️ 自定义/接人模式 (Overlay 终极修正版)
                    // ===========================
                    // 使用 firstTextBaseline 对齐，确保文字底部在一条线上
                    HStack(alignment: .firstTextBaseline, spacing: 0) {

                        // 1. 前缀 "Time2" 或 "Time2Pick "
                        Text(fixedPrefix)
                            .font(.system(size: customHeaderFontSize, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isTitleFocused = false
                                showPurposeMenu = true
                            }

                        // 2. 输入框 (使用 Overlay 方案确保贴合)
                        let textContent = textBinding.wrappedValue
                        
                        // 🟢 占位符区分模式
                        // 🔴 Pickup 模式改为 "Name"，比 "Someone" 短，避免太宽
                        let placeholder = purpose == .pickup
                            ? l10n.t("time2go.pickup_placeholder")
                            : l10n.t("time2go.custom_xxx_placeholder")
                            
                        let showText = textContent.isEmpty ? placeholder : textContent

                        // 🟢 技巧：给非中文(英文)加一个“瘦空格” (\u{2009})
                        let ghostText = (isChinese || isJapanese) ? showText : showText + "\u{2009}"

                        Text(ghostText)
                            .font(.system(size: customHeaderFontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(.clear) // 👈 隐身！只负责占位
                            .fixedSize(horizontal: true, vertical: false) // 强制跟随文字宽度
                            .padding(.horizontal, 0)
                            // 🛑 限制最大宽度，使用动态计算的 inputMaxWidth
                            .frame(maxWidth: inputMaxWidth, alignment: .center) // ✅ center
                            // ✨ 覆盖层：真正的输入框
                            .overlay(
                                TextField(
                                    placeholder,
                                    text: textBinding
                                )
                                .accentColor(.primary)
                                .font(.system(size: customHeaderFontSize, weight: .semibold, design: .monospaced))
                                .textFieldStyle(.plain)
                                .disableAutocorrection(true)
                                .textInputAutocapitalization(.words)
                                .lineLimit(1)
                                .focused($isTitleFocused)
                                // 填满底层 Text 提供的空间
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center) // ✅ center
                                .submitLabel(.done)
                                .onSubmit {
                                    isTitleFocused = false
                                },
                                alignment: .center // ✅ center
                            )
                            .layoutPriority(1)

                        // 3. 后缀 "啦" 或 " Up"
                        // 🟢 修改：只要有后缀就显示 (English Pickup 也有后缀 " Up")
                        if !fixedSuffixTail.isEmpty {
                            Text(fixedSuffixTail)
                                .font(.system(size: customHeaderFontSize, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isTitleFocused = false
                                    showPurposeMenu = true
                                }
                        }
                    }
                    // 🎨 整体修饰
                    .padding(.horizontal, 5)
                    .padding(.bottom, 5)
                    // 下划线
                    .background(
                        Rectangle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(height: 2)
                            .offset(y: 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isTitleFocused = false
                                showPurposeMenu = true
                            },
                        alignment: .bottom
                    )
                    // 强制整个 header 居中（含下划线）
                    .frame(maxWidth: .infinity, alignment: .center)

                } else {

                    // ===========================
                    // 🅱️ 普通模式
                    // ===========================
                    Button {
                        isTitleFocused = false
                        var tx = Transaction()
                        tx.animation = nil
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            showPurposeMenu = true
                        }
                    } label: {
                        Text(effectiveTitle)
                            .font(.system(size: 30, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 5)
                            .background(
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(height: 2),
                                alignment: .bottom
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            // 🟢 确保整个 Header 容器占满屏幕宽度
            .frame(maxWidth: .infinity)
            .padding(.top, headerTopPadding)
        }

        private var pickerSection: some View {
            VStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("time2go.date"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 5)
                        .padding(.bottom, 5)

                    Button {
                        tempSelectedDate = targetDate
                        isPickingDate = true
                        setOverlayActiveNoAnim(true)
                        withAnimation(.easeInOut(duration: 0.25)) { isDatePickerPresented = true }
                    } label: {
                        HStack {
                            Text(formattedDateDisplay)
                                .font(.title3.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(dateFieldBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(dateFieldBorder, lineWidth: 0.4)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 58)

                VStack(alignment: .leading, spacing: 0) {
                    Text(l10n.t("time2go.time"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 40)

                    DatePicker(
                        "",
                        selection: $targetDate,
                        in: timeRange,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: "en_GB"))
                    .frame(maxWidth: .infinity, maxHeight: 170)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
            }
        }

        private var bottomSection: some View {
            VStack(spacing: 20) {
                Text("\(l10n.t("time2go.in")) \(deltaText)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .center)

                Divider()
                    .padding(.horizontal, 45)
                    .opacity(0.3)

                PrimaryButton(
                    title: l10n.t("time2go.reset"),
                    icon: "arrow.counterclockwise",
                    isEnabled: canResetSelection,
                    action: {
                        let nm = ContentView.nextMinute()
                        isAutoUpdating = true
                        targetDate = nm
                        baselineSnapshot = nm
                        followNow = true
                        DispatchQueue.main.async { isAutoUpdating = false }
                    }
                )
                .padding(.horizontal, 50)

                PrimaryButton(
                    title: l10n.t("time2go.start"),
                    isEnabled: canStart,
                    action: {
                        // 2. 点击开始前，先检查是否有正在进行的任务
                        if SharedCountdownStore.load().isRunning {
                            showLimitAlert = true
                            return
                        }

                        // 原有逻辑
                        let fixed = max(targetDate, ContentView.nextMinute())
                        targetDate = fixed
                        onStart(effectiveTitle)
                    }
                )
                .padding(.horizontal, 50)
                // ✅ 保持原来的 28，不动布局
                .padding(.bottom, 28)
            }
        }

        private var dateOverlay: some View {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { dismissCalendar() }

                VStack(spacing: 0) {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.20)) { isDatePickerPresented = false }
                        } label: {
                            Text(l10n.t("time2go.cancel"))
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .padding(.leading, 16)
                        Spacer()
                        Button(action: applySelectedDate) {
                            Text(l10n.t("time2go.ok"))
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(minWidth: 80, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 5)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    Divider()
                    MinimalCalendar(selectedDate: $tempSelectedDate, allowedRange: dateRange)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .id(isDatePickerPresented ? "open" : "closed")
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .cornerRadius(30)
                .padding(.horizontal, 10)
                .padding(.bottom, 108)
                .frame(maxWidth: 345)
                .frame(maxHeight: .infinity, alignment: .bottom)
                // 🟢 ✅ 关键修复：这就是“挡箭牌”！
                // 加上这个空的点击事件，点击日历卡片时，事件就会被这里拦截，
                // 不会再穿透到背景去触发 dismissCalendar() 了。
                .contentShape(Rectangle()) // 确保整个区域都能拦截
                .onTapGesture {
                    // 什么都不做，只是为了拦截点击
                }
            }
        }

        private func applySelectedDate() {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: targetDate)
            let newDate = calendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: tempSelectedDate
            ) ?? tempSelectedDate
            isAutoUpdating = true
            targetDate = newDate
            baselineSnapshot = newDate
            isDatePickerPresented = false
            isPickingDate = false
            DispatchQueue.main.async { isAutoUpdating = false }
        }
    }
}

extension ContentView {
    struct CountdownScreen: View {
        @EnvironmentObject private var l10n: LocalizationManager
        let targetDate: Date
        let title: String
        let onCancel: () -> Void
        
        // 🆕 新增：自然结束的回调
        let onFinish: () -> Void
        
        @State private var now: Date = Date()
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        @Environment(\.scenePhase) private var scenePhase
        
        @State private var hasFinished = false

        private var remainingSeconds: Int {
            max(0, Int(targetDate.timeIntervalSince(now)))
        }

        private var formattedCountdown: String {
            let seconds = remainingSeconds
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            let s = seconds % 60
            if h > 0 {
                return String(format: "%02d:%02d:%02d", h, m, s)
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        }

        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    // 1. 标题
                    Text(title)
                        .font(.system(size: 35, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 20)
                    
                    // 2. 连接词
                    Text(l10n.t("time2go.in"))
                        .font(.system(size: 25, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(.secondaryLabel))
                    
                    // 3. 数字倒计时
                    Text(formattedCountdown)
                        .font(.system(size: 50, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                
                Spacer()
                
                VStack(spacing: 20) {
                    Divider()
                        .padding(.horizontal, 45)
                        .opacity(0.3)
                    PrimaryButton(
                        title: l10n.t("time2go.cancel"),
                        isEnabled: true,
                        action: { onCancel() }
                    )
                    .padding(.horizontal, 50)
                    .padding(.bottom, 98)
                }
            }
            .onReceive(timer) { value in now = value
                if remainingSeconds <= 0 && !hasFinished {
                    hasFinished = true
                    
                    // 🟢🟢🟢 改动：调用 onFinish，让界面返回 🟢🟢🟢
                    // 以前这里只发 Widget 更新，现在我们调用上层的 onFinish，
                    // 由上层统一处理“返回 + 结束 Activity”
                    onFinish()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    now = Date()
                }
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    init(title: String, icon: String? = nil, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }
    var body: some View {
        let bgColor: Color = {
            if !isEnabled {
                return colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
            }
            return colorScheme == .dark ? Color.white : Color.black
        }()
        let textColor: Color = colorScheme == .dark ? .black : .white
        Button(action: { guard isEnabled else { return }; action() }) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(bgColor))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(nil, value: isEnabled)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let l10n = LocalizationManager()
        return Group {
            ContentView(isOverlayActive: .constant(false)).environmentObject(l10n).preferredColorScheme(.light)
            ContentView(isOverlayActive: .constant(false)).environmentObject(l10n).preferredColorScheme(.dark)
        }
    }
}
