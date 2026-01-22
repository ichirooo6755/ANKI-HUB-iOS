import SwiftUI

/// テスト結果履歴ビュー
struct ExamHistoryView: View {
    @StateObject private var manager = ExamResultManager()
    @ObservedObject private var theme = ThemeManager.shared

    @State private var showAddSheet = false
    @State private var selectedResult: ExamResult? = nil
    @State private var filterType: ExamResult.ExamType? = nil

    var filteredResults: [ExamResult] {
        let sorted = manager.results.sorted { $0.date > $1.date }
        if let type = filterType {
            return sorted.filter { $0.type == type }
        }
        return sorted
    }

    var body: some View {
        ZStack {
            theme.background

            if manager.results.isEmpty {
                emptyStateView
            } else {
                resultsList
            }
        }
        .navigationTitle("テスト履歴")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("すべて") { filterType = nil }
                    ForEach(ExamResult.ExamType.allCases, id: \.self) { type in
                        Button(type.label) { filterType = type }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddExamResultSheet(manager: manager)
        }
        .sheet(item: $selectedResult) { result in
            ExamResultDetailSheet(result: result, manager: manager)
        }
        .applyAppTheme()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Text("テスト結果がありません")
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Button {
                showAddSheet = true
            } label: {
                Label("結果を追加", systemImage: "plus")
                    .font(.callout.weight(.semibold))
                    .padding()
                    .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                    .foregroundStyle(
                        theme.onColor(for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                    )
                    .cornerRadius(12)
            }
        }
    }

    private var resultsList: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("平均得点率")
                            .font(.footnote)
                            .foregroundStyle(theme.secondaryText)
                        Text("\(manager.getAveragePercent())%")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(theme.primaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("記録数")
                            .font(.footnote)
                            .foregroundStyle(theme.secondaryText)
                        Text("\(manager.results.count)")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(theme.primaryText)
                    }
                }
                .padding(.vertical, 8)
            }

            // Results List
            Section("結果一覧") {
                ForEach(filteredResults) { result in
                    Button {
                        selectedResult = result
                    } label: {
                        ExamResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let result = filteredResults[index]
                        manager.deleteResult(id: result.id)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listRowBackground(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }
}

struct ExamResultRow: View {
    let result: ExamResult
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.type.label)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                                .opacity(0.2)
                        )
                        .cornerRadius(4)

                    if !result.subject.isEmpty {
                        Text(result.subject)
                            .font(.footnote)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                if !result.university.isEmpty || !result.faculty.isEmpty {
                    Text(
                        [
                            result.university.isEmpty ? nil : result.university,
                            result.faculty.isEmpty ? nil : result.faculty,
                        ].compactMap { $0 }.joined(separator: " ")
                    )
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                }

                Text("\(result.year)年")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(result.percent)%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(percentColor(result.percent))

                Text("\(result.score)/\(result.total)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private func percentColor(_ percent: Int) -> Color {
        if percent >= 80 { return .green }
        if percent >= 60 { return .orange }
        return .red
    }
}

struct AddExamResultSheet: View {
    @ObservedObject var manager: ExamResultManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ThemeManager.shared

    let fixedDate: Date?

    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var type: ExamResult.ExamType = .common
    @State private var subject: String = ""
    @State private var university: String = ""
    @State private var faculty: String = ""
    @State private var score: Int = 0
    @State private var total: Int = 100
    @State private var reflection: String = ""

    init(manager: ExamResultManager, fixedDate: Date? = nil) {
        self.manager = manager
        self.fixedDate = fixedDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    Picker("年度", selection: $year) {
                        ForEach((2020...2030), id: \.self) { y in
                            Text("\(y)年").tag(y)
                        }
                    }

                    Picker("種別", selection: $type) {
                        ForEach(ExamResult.ExamType.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }

                    TextField("科目", text: $subject)
                    TextField("大学名", text: $university)
                    TextField("学部", text: $faculty)
                }

                Section("得点") {
                    Stepper(value: $score, in: 0...total) {
                        HStack {
                            Text("得点")
                            Spacer()
                            Text("\(score)点")
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityValue(Text("\(score)点"))

                    Stepper(value: $total, in: 1...500) {
                        HStack {
                            Text("満点")
                            Spacer()
                            Text("\(total)点")
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityValue(Text("\(total)点"))

                    if total > 0 {
                        let percent = Int(Double(score) / Double(total) * 100)
                        Text("得点率: \(percent)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Section("反省点・メモ") {
                    TextEditor(text: $reflection)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("結果を追加")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        manager.addResult(
                            year: year,
                            type: type,
                            subject: subject,
                            university: university,
                            faculty: faculty,
                            score: score,
                            total: total,
                            reflection: reflection,
                            date: fixedDate ?? Date()
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExamResultDetailSheet: View {
    let result: ExamResult
    @ObservedObject var manager: ExamResultManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ThemeManager.shared

    @State private var editedReflection: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("詳細") {
                    LabeledContent("種別", value: result.type.label)
                    LabeledContent("年度", value: "\(result.year)年")
                    if !result.subject.isEmpty {
                        LabeledContent("科目", value: result.subject)
                    }
                    if !result.university.isEmpty {
                        LabeledContent("大学名", value: result.university)
                    }
                    if !result.faculty.isEmpty {
                        LabeledContent("学部", value: result.faculty)
                    }
                    LabeledContent("得点", value: "\(result.score)/\(result.total)")
                    LabeledContent("得点率", value: "\(result.percent)%")

                    let formatter = DateFormatter()
                    let _ = formatter.dateStyle = .medium
                    LabeledContent("記録日", value: formatter.string(from: result.date))
                }

                Section("反省点・メモ") {
                    TextEditor(text: $editedReflection)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("テスト結果")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        manager.updateReflection(id: result.id, reflection: editedReflection)
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedReflection = result.reflection
            }
        }
    }
}

// Preview removed for macOS compatibility
