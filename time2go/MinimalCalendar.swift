import SwiftUI

struct MinimalCalendar: View {
    @Binding var selectedDate: Date
    let allowedRange: ClosedRange<Date>

    @State private var displayedMonth: Date = Date()

    @EnvironmentObject private var l10n: LocalizationManager

    private var monthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: displayedMonth)!
    }

    private var days: [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []

        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }

        var current = monthInterval.start
        while current < monthInterval.end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return dates
    }

    private static let weekdayKeys = [
        "calendar.weekday.mon",
        "calendar.weekday.tue",
        "calendar.weekday.wed",
        "calendar.weekday.thu",
        "calendar.weekday.fri",
        "calendar.weekday.sat",
        "calendar.weekday.sun"
    ]

    var body: some View {
        VStack(spacing: 12) {

            // 🟢 修改：加上了左右切换月份的按钮
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
                
                Text(monthTitle(displayedMonth))
                    .font(.headline)
                    .animation(nil, value: displayedMonth) // 防止文字变形
                
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            // 星期标题
            HStack {
                ForEach(Self.weekdayKeys, id: \.self) { key in
                    Text(l10n.t(key))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let firstWeekday = Calendar.current.component(.weekday, from: monthInterval.start)
            // 调整 offset 以匹配你的星期排列 (假设周一开头)
            // 如果你的日历是周日开头，逻辑可能不同，这里沿用你之前的逻辑
            let offset = (firstWeekday + 5) % 7

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {

                ForEach(0..<offset, id: \.self) { _ in
                    Color.clear.frame(height: 32)
                }

                ForEach(days, id: \.self) { day in
                    dayView(day)
                }
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            updateDisplayedMonth(to: selectedDate)
        }
        .environment(\.locale, l10n.locale)
        // 增加滑动手势切换月份 (可选体验优化)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        changeMonth(by: 1) // 左滑下个月
                    } else if value.translation.width > 50 {
                        changeMonth(by: -1) // 右滑上个月
                    }
                }
        )
    }
    
    // 🟢 新增：切换月份逻辑
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }
    
    private func updateDisplayedMonth(to date: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        displayedMonth = cal.date(from: comps) ?? date
    }

    private func dayView(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected     = cal.isDate(day, inSameDayAs: selectedDate)
        let isWithinRange  = allowedRange.contains(day)

        let textColor: Color = {
            if !isWithinRange { return .secondary.opacity(0.3) } // 范围外更淡一点
            if isSelected     { return .primary } // 适配深色模式，选中为主要颜色(反色)
            return .primary
        }()

        let backgroundColor: Color = isSelected
            ? .primary.opacity(0.15) // 选中背景
            : .clear

        return Text("\(cal.component(.day, from: day))")
            .frame(width: 32, height: 32)
            .font(.system(size: 16, weight: isSelected ? .bold : .medium))
            .foregroundColor(textColor)
            .background(
                Circle().fill(backgroundColor)
            )
            .contentShape(Circle()) // 增大点击热区
            .onTapGesture {
                guard isWithinRange else { return }
                
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDate = day
                }
            }
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = l10n.locale
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
