import SwiftUI

struct AppCalendarView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var stats = LearningStats.shared
    @State private var monthOffset: Int = 0
    @State private var activeSheet: CalendarSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 20) {
                        summaryCards

                        calendarCard

                        historyCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("カレンダー")
            .applyAppTheme()
            .sheet(item: $activeSheet) { sheet in
                switch sheet.kind {
                case .detail:
                    DayDetailSheet(
                        date: sheet.date,
                        stats: stats,
                        onEdit: { activeSheet = CalendarSheet(date: sheet.date, kind: .edit) }
                    )
                case .edit:
                    DayEditSheet(date: sheet.date, stats: stats)
                }
            }
        }
    }

    private struct CalendarSheet: Identifiable {
        enum Kind {
            case detail
            case edit
        }

        let date: Date
        let kind: Kind

        var id: String {
            "\(Self.dateKey(date))_\(kind == .detail ? "detail" : "edit")"
        }

        private static func dateKey(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }

    private struct DayDetailSheet: View {
        let date: Date
        @ObservedObject var stats: LearningStats
        let onEdit: () -> Void

        @Environment(\.dismiss) private var dismiss
        @ObservedObject private var theme = ThemeManager.shared
        @StateObject private var todoManager = TodoManager()
        @StateObject private var examManager = ExamResultManager()

        @State private var showAddExamSheet = false
        @State private var selectedExamResult: ExamResult? = nil

        @State private var newTaskTitle: String = ""

        private var key: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }

        private var entry: LearningStats.DailyEntry? {
            stats.dailyHistory[key]
        }

        private var journal: LearningStats.JournalEntry? {
            stats.journals[key]
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let minutes = entry?.minutes ?? 0
                        let words = entry?.words ?? 0
                        metricRow(title: "学習時間", value: "\(minutes)", unit: "分")
                        metricRow(title: "学習語数", value: "\(words)", unit: "語")

                        if let subjects = entry?.subjects, !subjects.isEmpty {
                            subjectBreakdown(subjects)
                        }

                        dayExams

                        dayTasks

                        if let journal {
                            journalSection(journal)
                        }
                    }
                    .padding(16)
                }
                .navigationTitle(dateTitle)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("編集") {
                            onEdit()
                        }
                    }
                }
                .background(theme.background)
            }
            .sheet(isPresented: $showAddExamSheet) {
                AddExamResultSheet(manager: examManager, fixedDate: date)
            }
            .sheet(item: $selectedExamResult) { result in
                ExamResultDetailSheet(result: result, manager: examManager)
            }
        }

        private var dayExams: some View {
            let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
            let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
            let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
            let items = examManager.results(forDay: date)

            return VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("テスト")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Button {
                        showAddExamSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(theme.onColor(for: primary))
                            .frame(width: 32, height: 32)
                            .background(primary, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                if !items.isEmpty {
                    ForEach(items) { result in
                        Button {
                            selectedExamResult = result
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.type.label)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(theme.primaryText)
                                    if !result.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(result.subject)
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                                Spacer()
                                Text("\(result.percent)%")
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(theme.primaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(border.opacity(0.5), lineWidth: 1)
            )
        }

        private var dayTasks: some View {
            let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
            let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
            let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
            let items = tasksForDay

            return VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ToDo")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                }

                if !items.isEmpty {
                    ForEach(items) { item in
                        Button {
                            todoManager.toggleItem(id: item.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? accent.opacity(0.9) : theme.secondaryText)
                                Text(item.title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(theme.primaryText)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    TextField("", text: $newTaskTitle)
                        .textFieldStyle(.plain)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .submitLabel(.done)
                        .onSubmit { addTaskIfPossible() }

                    Button {
                        addTaskIfPossible()
                    } label: {
                        Image(systemName: "plus")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(theme.onColor(for: accent))
                            .frame(width: 34, height: 34)
                            .background(accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(surface.opacity(theme.effectiveIsDark ? 0.70 : 0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(border.opacity(0.45), lineWidth: 1)
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(border.opacity(0.5), lineWidth: 1)
            )
        }

        private var tasksForDay: [TodoItem] {
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
            return todoManager.items
                .filter { item in
                    guard let due = item.dueDate else { return false }
                    let d = calendar.startOfDay(for: due)
                    return d >= dayStart && d < nextDay
                }
                .sorted { a, b in
                    if a.isCompleted != b.isCompleted { return !a.isCompleted }
                    return a.createdAt < b.createdAt
                }
        }

        private func addTaskIfPossible() {
            let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            todoManager.addItem(title: trimmed, dueDate: date, priority: .medium)
            newTaskTitle = ""
        }

        private func metricRow(title: String, value: String, unit: String) -> some View {
            let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
            let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
            return HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 44, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(unit)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(border.opacity(0.5), lineWidth: 1)
            )
        }

        private func subjectBreakdown(_ subjects: [String: Int]) -> some View {
            let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
            let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
            let sorted = subjects.sorted { $0.value > $1.value }

            return VStack(alignment: .leading, spacing: 10) {
                Text("科目")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.secondaryText)

                ForEach(sorted, id: \.key) { pair in
                    HStack {
                        Text(Subject(rawValue: pair.key)?.displayName ?? pair.key)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Text("\(pair.value)")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(theme.primaryText)
                        Text("語")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(border.opacity(0.5), lineWidth: 1)
            )
        }

        private func journalSection(_ journal: LearningStats.JournalEntry) -> some View {
            let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
            let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)

            return VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: journal.mood.symbol)
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    Text(journal.mood.label)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                }

                if !journal.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(journal.note)
                        .font(.callout)
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(border.opacity(0.5), lineWidth: 1)
            )
        }

        private var dateTitle: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
    }

    private struct DayEditSheet: View {
        let date: Date
        @ObservedObject var stats: LearningStats
        @Environment(\.dismiss) private var dismiss

        @State private var minutes: Int
        @State private var words: Int
        @State private var selectedMood: LearningStats.Mood
        @State private var note: String
        private let subjects: [String: Int]

        init(date: Date, stats: LearningStats) {
            self.date = date
            self.stats = stats
            let key = Self.dateKey(date)
            let entry = stats.dailyHistory[key]
            let journal = stats.journals[key]
            _minutes = State(initialValue: entry?.minutes ?? 0)
            _words = State(initialValue: entry?.words ?? 0)
            _selectedMood = State(initialValue: journal?.mood ?? .neutral)
            _note = State(initialValue: journal?.note ?? "")
            subjects = entry?.subjects ?? [:]
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        Stepper(value: $minutes, in: 0...600) {
                            HStack {
                                Text("学習時間")
                                Spacer()
                                Text("\(minutes)分")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Stepper(value: $words, in: 0...1000) {
                            HStack {
                                Text("学習語数")
                                Spacer()
                                Text("\(words)語")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("学習記録")
                    }

                    Section {
                        Picker("気分", selection: $selectedMood) {
                            ForEach(LearningStats.Mood.allCases) { mood in
                                Label(mood.label, systemImage: mood.symbol)
                                    .tag(mood)
                            }
                        }
                        .pickerStyle(.menu)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $note)
                                .frame(minHeight: 120)
                            if note.isEmpty {
                                Text("メモを入力")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                    } header: {
                        Text("ジャーナル")
                    }
                }
                .navigationTitle(dateTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            save()
                        }
                    }
                }
            }
        }

        private var dateTitle: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }

        private func save() {
            let key = Self.dateKey(date)
            stats.setDailyEntry(dateKey: key, words: words, minutes: minutes, subjects: subjects)
            stats.setJournalEntry(dateKey: key, mood: selectedMood, note: note)
            dismiss()
        }

        private static func dateKey(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }

    private var calendarCard: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        let days = monthDays

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("カレンダー")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .accessibilityAddTraits(.isHeader)
                }
                .layoutPriority(1)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        monthOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30)
                            .background(accent.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(accent.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(monthTitle)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)
                        .frame(minWidth: 80)
                        .lineLimit(1)

                    Button {
                        monthOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(accent)
                            .frame(width: 30, height: 30)
                            .background(accent.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(accent.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days) { day in
                    if let date = day.date {
                        Button {
                            activeSheet = CalendarSheet(date: date, kind: .detail)
                        } label: {
                            DayCell(
                                date: date,
                                activity: activityLevel(for: stats.dailyHistory[dateKey(date)]),
                                hasJournal: stats.journals[dateKey(date)] != nil,
                                isToday: Calendar.current.isDateInToday(date)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [surface.opacity(0.98), highlight.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private var summaryCards: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let secondary = theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                CalendarStatCard(
                    title: "今日の学習",
                    value: "\(stats.todayMinutes)",
                    unit: "分",
                    icon: "clock.fill",
                    color: accent
                )
                CalendarStatCard(
                    title: "連続日数",
                    value: "\(stats.streak)",
                    unit: "日",
                    icon: "flame.fill",
                    color: primary
                )
            }

            HStack(spacing: 12) {
                CalendarStatCard(
                    title: "習得語彙",
                    value: "\(stats.masteredCount)",
                    unit: "語",
                    icon: "checkmark.seal.fill",
                    color: mastered
                )
                CalendarStatCard(
                    title: "総単語数",
                    value: "\(stats.totalWords)",
                    unit: "語",
                    icon: "books.vertical.fill",
                    color: secondary
                )
            }
        }
    }

    private var historyCard: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let highlight = theme.currentPalette.color(.background, isDark: theme.effectiveIsDark)
        let days = recentDays

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("学習履歴")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .accessibilityAddTraits(.isHeader)
                }
                .layoutPriority(1)
                Spacer()
            }

            if stats.dailyHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("まだ学習記録がありません")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    NavigationLink(destination: TimerView()) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.footnote.weight(.semibold))
                            Text("タイマーを起動")
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(theme.onColor(for: accent))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(accent.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                    spacing: 6
                ) {
                    ForEach(days) { day in
                        Button {
                            activeSheet = CalendarSheet(date: day.date, kind: .detail)
                        } label: {
                            DayCell(
                                date: day.date,
                                activity: day.activity,
                                hasJournal: day.hasJournal,
                                isToday: day.isToday
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("記録日数: \(stats.dailyHistory.count)日")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("学習量")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        Text("少")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                        ForEach(0..<4) { level in
                            HeatmapLegendCell(
                                level: level,
                                accent: accent,
                                surface: surface
                            )
                        }
                        Text("多")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [surface.opacity(0.98), highlight.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private var recentDays: [DaySnapshot] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<21).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = dateKey(date)
            let entry = stats.dailyHistory[key]
            let activity = activityLevel(for: entry)
            let hasJournal = stats.journals[key] != nil
            return DaySnapshot(
                date: date,
                activity: activity,
                hasJournal: hasJournal,
                isToday: calendar.isDateInToday(date)
            )
        }
        .reversed()
    }

    private var weekdays: [String] {
        let calendar = Calendar.current
        let base = ["日", "月", "火", "水", "木", "金", "土"]
        let startIndex = (calendar.firstWeekday - 1 + base.count) % base.count
        return Array(base[startIndex...] + base[..<startIndex])
    }

    private var displayedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: displayedMonth)
    }

    private var monthDays: [CalendarDay] {
        let calendar = Calendar.current
        let start = startOfMonth(displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: start)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarDay] = Array(repeating: CalendarDay(date: nil), count: leadingEmpty)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                days.append(CalendarDay(date: date))
            }
        }

        let trailingEmpty = (7 - (days.count % 7)) % 7
        if trailingEmpty > 0 {
            days.append(contentsOf: Array(repeating: CalendarDay(date: nil), count: trailingEmpty))
        }

        return days
    }

    private func activityLevel(for entry: LearningStats.DailyEntry?) -> Int {
        let minutes = entry?.minutes ?? 0
        let words = entry?.words ?? 0
        if minutes >= 60 || words >= 80 { return 3 }
        if minutes >= 30 || words >= 40 { return 2 }
        if minutes > 0 || words > 0 { return 1 }
        return 0
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func heatmapColor(level: Int, accent: Color, surface: Color) -> Color {
        switch level {
        case 1:
            return accent.opacity(0.25)
        case 2:
            return accent.opacity(0.55)
        case 3:
            return accent.opacity(0.9)
        default:
            return surface.opacity(0.4)
        }
    }

    private struct HeatmapLegendCell: View {
        let level: Int
        let accent: Color
        let surface: Color

        var body: some View {
            let size: CGFloat = 12
            let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
            shape
                .fill(color)
                .frame(width: size, height: size)
                .overlay(
                    shape
                        .stroke(accent.opacity(level == 0 ? 0.08 : 0), lineWidth: 1)
                )
        }

        private var color: Color {
            switch level {
            case 1:
                return accent.opacity(0.25)
            case 2:
                return accent.opacity(0.55)
            case 3:
                return accent.opacity(0.9)
            default:
                return surface.opacity(0.4)
            }
        }
    }

    private struct DaySnapshot: Identifiable {
        let id = UUID()
        let date: Date
        let activity: Int
        let hasJournal: Bool
        let isToday: Bool
    }

    private struct CalendarEditDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    private struct CalendarDay: Identifiable {
        let id = UUID()
        let date: Date?
    }
}
