import SwiftUI
import Charts

struct PastExamAnalysisView: View {
    @StateObject private var manager = ExamResultManager()
    @State private var selectedTab = "score"

    @ObservedObject private var theme = ThemeManager.shared

    private var primaryColor: Color { theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark) }
    private var accentColor: Color { theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark) }
    private var selectionColor: Color { theme.currentPalette.color(.selection, isDark: theme.effectiveIsDark) }
    private var surfaceColor: Color { theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark) }
    private var borderColor: Color { theme.currentPalette.color(.border, isDark: theme.effectiveIsDark) }
    private var weakColor: Color { theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark) }
    private var masteredColor: Color { theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark) }
    private func onText(for bg: Color) -> Color { theme.onColor(for: bg) }
    
    // Add Score State
    @State private var inputYear = "2024"
    @State private var inputType: ExamResult.ExamType = .common
    @State private var inputSubject = ""
    @State private var inputUniversity = ""
    @State private var inputFaculty = ""
    @State private var inputScore = ""
    @State private var inputTotal = "100"
    
    // Analyzer State
    @State private var analyzeText = ""
    @State private var analysisResult: AnalysisResult?
    
    // Trend State
    @State private var trendText = ""
    @State private var trendResult: TrendResult?
    
    // Points State
    @State private var pointsTotal = "200"
    @State private var pointsSections = "6"
    @State private var calculatedPoints: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        TabButton(title: "スコア管理", id: "score", selected: $selectedTab)
                        TabButton(title: "文章分析", id: "analyze", selected: $selectedTab)
                        TabButton(title: "傾向分析", id: "trend", selected: $selectedTab)
                        TabButton(title: "配点予測", id: "points", selected: $selectedTab)
                    }
                    .padding(.horizontal)
                }
                
                if selectedTab == "score" {
                    ScoreTrackerView
                } else if selectedTab == "analyze" {
                    TextAnalyzerView
                } else if selectedTab == "trend" {
                    TrendAnalyzerView
                } else if selectedTab == "points" {
                    PointPredictorView
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("過去問解析")
        .background(ThemeManager.shared.background)
    }
    
    // MARK: - Tab 1: Score Tracker
    var ScoreTrackerView: some View {
        VStack(spacing: 20) {
            // Input
            VStack(alignment: .leading, spacing: 15) {
                Text("新しい記録を追加")
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.primaryText)
                
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading) {
                        Text("年度")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                        TextField("2024", text: $inputYear)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .monospacedDigit()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    .frame(width: 80)
                    
                    VStack(alignment: .leading) {
                        Text("種類")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                        Picker("Type", selection: $inputType) {
                            ForEach(ExamResult.ExamType.allCases, id: \.self) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .background(surfaceColor.opacity(theme.effectiveIsDark ? 0.6 : 1.0))
                        .cornerRadius(8)
                    }
                }
                
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading) {
                        Text("点数 / 満点")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                        HStack {
                            TextField("点数", text: $inputScore)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .monospacedDigit()
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                            Text("/")
                            TextField("満点", text: $inputTotal)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .monospacedDigit()
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .frame(width: 60)
                        }
                    }
                    
                    Button(action: addScore) {
                        Text("記録")
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(primaryColor)
                            .foregroundStyle(onText(for: primaryColor))
                            .cornerRadius(8)
                    }
                    .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("科目/大学/学部")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                    TextField("科目", text: $inputSubject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("大学名", text: $inputUniversity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("学部", text: $inputFaculty)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding()
            .background(ThemeManager.shared.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal)
            
            // Chart
            if !manager.results.isEmpty {
                VStack(alignment: .leading) {
                    Text("スコア推移")
                        .font(.headline)
                        .foregroundColor(ThemeManager.shared.primaryText)
                        .padding(.bottom)
                    
                    Chart(manager.results.sorted(by: { $0.date < $1.date })) { res in
                        LineMark(
                            x: .value("Date", res.date),
                            y: .value("Percent", res.percent)
                        )
                        .foregroundStyle(primaryColor)
                        .symbol(Circle())
                        
                        AreaMark(
                            x: .value("Date", res.date),
                            y: .value("Percent", res.percent)
                        )
                        .foregroundStyle(primaryColor.opacity(0.1))
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("得点率", position: .leading)
                    .chartXAxisLabel("年度")
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(borderColor.opacity(0.25))
                            AxisTick()
                            AxisValueLabel {
                                if let percent = value.as(Double.self) {
                                    Text("\(Int(percent))%")
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                                .foregroundStyle(borderColor.opacity(0.15))
                            AxisTick()
                            AxisValueLabel(format: .dateTime.year())
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            
            // List
            LazyVStack(spacing: 10) {
                ForEach(manager.results.sorted(by: { $0.date > $1.date })) { res in
                    HStack {
                        Text("\(res.percent)%")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(primaryColor)
                            .frame(width: 60, alignment: .center)
                        
                        VStack(alignment: .leading) {
                            Text("\(res.year)年度 \(res.type.label)")
                                .font(.headline)
                                .foregroundColor(ThemeManager.shared.primaryText)
                            if !res.subject.isEmpty || !res.university.isEmpty || !res.faculty.isEmpty {
                                Text(
                                    [
                                        res.subject.isEmpty ? nil : res.subject,
                                        res.university.isEmpty ? nil : res.university,
                                        res.faculty.isEmpty ? nil : res.faculty,
                                    ].compactMap { $0 }.joined(separator: " ")
                                )
                                .font(.footnote)
                                .foregroundColor(ThemeManager.shared.secondaryText)
                            }
                            Text("\(res.score)/\(res.total)点")
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundColor(ThemeManager.shared.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button(action: { manager.deleteResult(id: res.id) }) {
                            Image(systemName: "xmark")
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .padding()
                    .background(ThemeManager.shared.cardBackground)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Tab 2: Text Analyzer
    var TextAnalyzerView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("英文を貼り付け")
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.primaryText)
                TextEditor(text: $analyzeText)
                    .frame(height: 150)
                    .padding(4)
                    .background(surfaceColor.opacity(theme.effectiveIsDark ? 0.6 : 1.0))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor.opacity(0.6)))
                
                Button(action: analyze) {
                    Text("分析開始")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [primaryColor, accentColor], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(onText(for: primaryColor))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(ThemeManager.shared.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal)
            
            if let res = analysisResult {
                VStack(spacing: 15) {
                    HStack {
                        StatBox(val: "\(res.total)", label: "総単語数")
                        StatBox(val: "\(res.learning)", label: "難単語(推測)", color: .orange)
                    }
                    
                    Text("分析結果 (簡易版)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(res.analyzedText) // In a real app, this would be AttributedText
                        .font(.body)
                        .foregroundColor(ThemeManager.shared.primaryText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(surfaceColor.opacity(theme.effectiveIsDark ? 0.35 : 0.6))
                        .cornerRadius(8)
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Tab 3: Trend Analyzer
    var TrendAnalyzerView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("過去問の英文を貼り付け")
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.primaryText)
                TextEditor(text: $trendText)
                    .frame(height: 150)
                    .padding(4)
                    .background(surfaceColor.opacity(theme.effectiveIsDark ? 0.6 : 1.0))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor.opacity(0.6)))
                
                Button(action: analyzeTrend) {
                    Text("傾向を分析")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [masteredColor, selectionColor], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(onText(for: masteredColor))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(ThemeManager.shared.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal)
            
            if let res = trendResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text("文法項目出現数").font(.headline)
                    ForEach(res.grammarCounts.sorted(by: { $0.value > $1.value }), id: \.key) { key, val in
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(val)")
                        }
                    }
                }
                .padding()
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Tab 4: Point Predictor
    var PointPredictorView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("配点予測計算機")
                    .font(.headline)
                    .padding(.bottom)
                
                HStack {
                    TextField("満点", text: $pointsTotal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("大問数", text: $pointsSections)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button(action: calculatePoints) {
                    Text("計算")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [accentColor, weakColor], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(onText(for: accentColor))
                        .cornerRadius(12)
                }
                
                if !calculatedPoints.isEmpty {
                    Text(calculatedPoints)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(ThemeManager.shared.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Actions
    
    func addScore() {
        guard let year = Int(inputYear), let score = Int(inputScore), let total = Int(inputTotal) else { return }
        manager.addResult(
            year: year,
            type: inputType,
            subject: inputSubject,
            university: inputUniversity,
            faculty: inputFaculty,
            score: score,
            total: total,
            reflection: ""
        )
        inputScore = ""
    }
    
    struct AnalysisResult {
        let total: Int
        let learning: Int
        let analyzedText: String
    }
    
    func analyze() {
        let words = analyzeText.split { $0.isWhitespace || $0.isPunctuation }
        let count = words.count
        let longWords = words.filter { $0.count > 7 }.count
        analysisResult = AnalysisResult(total: count, learning: longWords, analyzedText: analyzeText)
        // Note: Real highlighter needs AttributedString logic, simplified here
    }
    
    struct TrendResult {
        let grammarCounts: [String: Int]
    }
    
    func analyzeTrend() {
        // Simple regex mockup
        var counts: [String: Int] = [:]
        let patterns: [String: String] = [
            "完了形": "have|has|had",
            "関係詞": "which|who|that",
            "受動態": "been|being",
            "助動詞": "can|could|will|would"
        ]
        
        for (name, pat) in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                let matches = regex.numberOfMatches(in: trendText, range: NSRange(trendText.startIndex..., in: trendText))
                if matches > 0 {
                    counts[name] = matches
                }
            }
        }
        trendResult = TrendResult(grammarCounts: counts)
    }
    
    func calculatePoints() {
        guard let total = Int(pointsTotal), let sects = Int(pointsSections), sects > 0 else { return }
        let avg = total / sects
        calculatedPoints = "均等割: \(avg)点 / 大問"
    }
}

// Helper Views
struct TabButton: View {
    let title: String
    let id: String
    @Binding var selected: String

    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let onColoredBackgroundText: Color = theme.onColor(for: primary)
        Button(action: { selected = id }) {
            Text(title)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected == id ? primary : surface)
                .foregroundStyle(selected == id ? onColoredBackgroundText : ThemeManager.shared.primaryText)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(border.opacity(selected == id ? 0.0 : 0.6), lineWidth: 1)
                )
        }
    }
}

struct StatBox: View {
    let val: String
    let label: String
    var color: Color = .black
    
    var body: some View {
        let theme = ThemeManager.shared
        let isDark = theme.effectiveIsDark
        let bg = theme.currentPalette.color(.surface, isDark: isDark).opacity(isDark ? 0.6 : 1.0)
        VStack {
            Text(val)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundColor(color == .black ? theme.primaryText : color)
            Text(label)
                .font(.footnote)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(bg)
        .cornerRadius(12)
    }
}
