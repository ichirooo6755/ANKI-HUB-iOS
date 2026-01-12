import Charts
import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var learningStats: LearningStats
    @ObservedObject var theme = ThemeManager.shared

    @State private var currentMonth: Date = Date()

    @State private var showEditSheet: Bool = false
    @State private var editingDate: Date = Date()
    @State private var editingWords: String = "0"
    @State private var editingMinutes: String = "0"
    @State private var editingEnglish: String = "0"
    @State private var editingEiken: String = "0"
    @State private var editingKobun: String = "0"
    @State private var editingKanbun: String = "0"
    @State private var editingSeikei: String = "0"

    // Grid Layout
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 24) {
                        // Summary Stats
                        HStack(spacing: 20) {
                            StatCard(
                                title: "Current Streak", value: "\(learningStats.streak)",
                                unit: "days", icon: "flame.fill", color: .orange)
                            StatCard(
                                title: "Today's Focus", value: "\(learningStats.todayMinutes)",
                                unit: "min", icon: "hourglass", color: .blue)
                        }
                        .padding(.horizontal)

                        // Calendar Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(monthYearString(from: currentMonth))
                                    .font(.title2.bold())

                                Spacer()

                                HStack(spacing: 20) {
                                    Button(action: { changeMonth(by: -1) }) {
                                        Image(systemName: "chevron.left")
                                    }
                                    Button(action: { changeMonth(by: 1) }) {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Days of Week
                            HStack {
                                ForEach(
                                    ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self
                                ) { day in
                                    Text(day)
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            // Dates Grid
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(daysInMonth(for: currentMonth), id: \.self) { date in
                                    if let date = date {
                                        Button {
                                            openEdit(for: date)
                                        } label: {
                                            DayCell(date: date, activity: getActivity(for: date))
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Color.clear.frame(height: 30)
                                    }
                                }
                            }
                        }
                        .padding()
                        .liquidGlass()
                        .padding(.horizontal)

                        // Activity Chart (Last 7 Days)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Weekly Activity")
                                .font(.headline)

                            if #available(iOS 16.0, *) {
                                Chart {
                                    ForEach(last7Days(), id: \.date) { item in
                                        BarMark(
                                            x: .value("Day", item.dayLabel),
                                            y: .value("Minutes", item.minutes)
                                        )
                                        .foregroundStyle(
                                            theme.currentPalette.color(
                                                .primary,
                                                isDark: theme.effectiveIsDark
                                            )
                                        )
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 180)
                            } else {
                                Text("Charts require iOS 16+")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .liquidGlass()
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Calendar")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section("日付") {
                            Text(dateString(from: editingDate))
                                .foregroundStyle(.secondary)
                        }

                        Section("合計") {
                            TextField("単語数", text: $editingWords)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                            TextField("学習分数", text: $editingMinutes)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                        }

                        Section("科目別（単語数）") {
                            TextField("英単語", text: $editingEnglish)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                            TextField("英検", text: $editingEiken)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                            TextField("古文", text: $editingKobun)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                            TextField("漢文", text: $editingKanbun)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                            TextField("政経", text: $editingSeikei)
                                #if os(iOS)
                                    .keyboardType(.numberPad)
                                #endif
                        }
                    }
                    .navigationTitle("学習記録")
                    #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") {
                                showEditSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                saveEdit()
                                showEditSheet = false
                            }
                        }
                    }
                }
            }
        }
        .applyAppTheme()
    }

    // MARK: - Subviews

    struct StatCard: View {
        let title: String
        let value: String
        let unit: String
        let icon: String
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass()
        }
    }

    struct DayCell: View {
        let date: Date
        let activity: Int  // 0: none, 1: low, 2: medium, 3: high

        var body: some View {
            ZStack {
                Circle()
                    .fill(activityColor(activity).opacity(activity > 0 ? 0.8 : 0.05))
                    .frame(height: 35)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption)
                    .foregroundStyle(activity > 0 ? .white : .primary)
            }
        }

        func activityColor(_ level: Int) -> Color {
            switch level {
            case 0: return .gray
            case 1: return .green.opacity(0.4)
            case 2: return .green.opacity(0.7)
            case 3: return .green
            default: return .gray
            }
        }
    }

    // MARK: - Helpers

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func openEdit(for date: Date) {
        editingDate = date
        let key = dateString(from: date)

        let entry = learningStats.dailyHistory[key]
        editingWords = String(entry?.words ?? 0)
        editingMinutes = String(entry?.minutes ?? 0)
        editingEnglish = String(entry?.subjects[Subject.english.rawValue] ?? 0)
        editingEiken = String(entry?.subjects[Subject.eiken.rawValue] ?? 0)
        editingKobun = String(entry?.subjects[Subject.kobun.rawValue] ?? 0)
        editingKanbun = String(entry?.subjects[Subject.kanbun.rawValue] ?? 0)
        editingSeikei = String(entry?.subjects[Subject.seikei.rawValue] ?? 0)

        showEditSheet = true
    }

    private func saveEdit() {
        let key = dateString(from: editingDate)
        let words = Int(editingWords) ?? 0
        let minutes = Int(editingMinutes) ?? 0
        let subjects: [String: Int] = [
            Subject.english.rawValue: Int(editingEnglish) ?? 0,
            Subject.eiken.rawValue: Int(editingEiken) ?? 0,
            Subject.kobun.rawValue: Int(editingKobun) ?? 0,
            Subject.kanbun.rawValue: Int(editingKanbun) ?? 0,
            Subject.seikei.rawValue: Int(editingSeikei) ?? 0,
        ]

        learningStats.setDailyEntry(
            dateKey: key, words: words, minutes: minutes, subjects: subjects)
    }

    private func getActivity(for date: Date) -> Int {
        let key = dateString(from: date)
        guard let entry = learningStats.dailyHistory[key] else { return 0 }

        if entry.words > 50 { return 3 }
        if entry.words > 20 { return 2 }
        if entry.words > 0 { return 1 }
        return 0
    }

    private func daysInMonth(for date: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
            let firstDayOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: date))
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)  // 1 = Sun, 2 = Mon
        let daysBefore = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: daysBefore)

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    struct ChartData {
        let date: Date
        let dayLabel: String
        let minutes: Int
    }

    private func last7Days() -> [ChartData] {
        var data: [ChartData] = []
        let calendar = Calendar.current
        let today = Date()

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = dateString(from: date)
                let minutes = learningStats.dailyHistory[key]?.minutes ?? 0

                let formatter = DateFormatter()
                formatter.dateFormat = "E"
                let label = formatter.string(from: date)

                data.append(ChartData(date: date, dayLabel: label, minutes: minutes))
            }
        }
        return data
    }
}

// Preview removed for macOS compatibility
