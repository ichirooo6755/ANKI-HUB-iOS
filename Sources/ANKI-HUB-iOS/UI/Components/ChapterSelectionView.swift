import SwiftUI

struct ChapterSelectionView: View {
    let subject: Subject
    @State private var chapters: [Chapter] = []

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var masteryTracker = MasteryTracker.shared
    
    struct Chapter: Identifiable {
        let id: String  // Deterministic ID to prevent view recreation
        let title: String
        let description: String
        let progress: Double
        let isLocked: Bool
        
        init(title: String, description: String, progress: Double, isLocked: Bool) {
            self.id = title  // Use title as stable ID
            self.title = title
            self.description = description
            self.progress = progress
            self.isLocked = isLocked
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(chapters) { chapter in
                    NavigationLink(destination: QuizView(subject: subject, chapter: chapter.title)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.headline)
                                Text(chapter.description)
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            if chapter.isLocked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(theme.secondaryText)
                            } else {
                                CircularProgressView(progress: chapter.progress, lineWidth: 3)
                                    .frame(width: 30, height: 30)
                            }
                        }
                        .padding()
                        .liquidGlass()
                    }
                    .disabled(chapter.isLocked)
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(theme.background)
        .navigationTitle("\(subject.displayName) - チャプター")
        .onAppear {
            loadChapters()
        }
        .onReceive(masteryTracker.$items) { _ in
            loadChapters()
        }
        .applyAppTheme()
    }
    
    func loadChapters() {
        if subject == .english {
            // English: 1900 words in 38 chapters (50 words per chapter)
            chapters = (1...38).map { i in
                let start = (i - 1) * 50 + 1
                let end = min(i * 50, 1900)
                return Chapter(
                    title: "STAGE\(i)",
                    description: "単語 \(start) - \(end)",
                    progress: getProgress(for: subject, chapterId: i),
                    isLocked: false // English chapters are always unlocked
                )
            }
        } else if subject == .kobun {
            // Kobun: dynamic chapters (50 words/chapter)
            let total = VocabularyData.shared.getVocabulary(for: .kobun).count
            guard total > 0 else {
                chapters = []
                return
            }
            let totalChapters = Int(ceil(Double(total) / 50.0))
            chapters = (1...totalChapters).map { i in
                let start = (i - 1) * 50 + 1
                let end = min(i * 50, total)
                return Chapter(
                    title: "チャプター \(i)（\(start)-\(end)）",
                    description: "単語 \(start) - \(end)",
                    progress: getProgress(for: subject, chapterId: i),
                    isLocked: false // All chapters unlocked
                )
            }
        } else if subject == .kanbun {
            // Kanbun: use production data as-is.
            // If the dataset has categories, expose them as chapters; otherwise provide a single "すべて" chapter.
            let vocab = VocabularyData.shared.getVocabulary(for: .kanbun)
            let categories = Array(Set(vocab.compactMap { $0.category }.filter { !$0.isEmpty }))
                .sorted()

            if !categories.isEmpty {
                chapters = categories.map { cat in
                    Chapter(
                        title: cat,
                        description: "カテゴリ",
                        progress: 0,
                        isLocked: false
                    )
                }
            } else {
                chapters = [
                    Chapter(
                        title: "すべて",
                        description: "全範囲",
                        progress: 0,
                        isLocked: false
                    )
                ]
            }
        } else if subject == .seikei {
            // Seikei: 8 Chapters from README.md
            let seikeiChapters = [
                (1, "1-25", "天皇・戦争放棄・基本的人権"),
                (2, "26-50", "国民の権利義務・国会"),
                (3, "51-75", "国会・内閣"),
                (4, "76-100", "司法・財政・地方自治"),
                (5, "101-125", "改正・最高法規"),
                (6, "126-150", "経済分野"),
                (7, "151-175", "政治分野"),
                (8, "176-200", "国際関係")
            ]
            
            chapters = seikeiChapters.map { (id, range, desc) in
                Chapter(
                    title: "Chapter \(id) (\(range)条)",
                    description: desc,
                    progress: getProgress(for: subject, chapterId: id),
                    isLocked: id > 1 && getProgress(for: subject, chapterId: id-1) < 0.8
                )
            }
        } else {
            chapters = []
        }
    }
    
    func getProgress(for subject: Subject, chapterId: Int) -> Double {
        let mastery = masteryTracker.items[subject.rawValue] ?? [:]

        func isCompleted(_ item: MasteryItem?) -> Bool {
            guard let item else { return false }
            return item.mastery == .almost || item.mastery == .mastered
        }

        switch subject {
        case .english, .kobun:
            let vocab = VocabularyData.shared.getVocabulary(for: subject)
            guard !vocab.isEmpty else { return 0 }
            let startIndex = max(0, (chapterId - 1) * 50)
            let endIndex = min(chapterId * 50, vocab.count)
            guard startIndex < endIndex else { return 0 }
            let slice = vocab[startIndex..<endIndex]
            let total = slice.count
            let completed = slice.reduce(0) { acc, v in
                acc + (isCompleted(mastery[v.id]) ? 1 : 0)
            }
            return total > 0 ? Double(completed) / Double(total) : 0

        case .kanbun:
            let vocab = VocabularyData.shared.getVocabulary(for: subject)
            guard !vocab.isEmpty else { return 0 }
            let groups = 4
            let groupSize = Int(ceil(Double(vocab.count) / Double(groups)))
            let startIndex = max(0, (chapterId - 1) * groupSize)
            let endIndex = min(chapterId * groupSize, vocab.count)
            guard startIndex < endIndex else { return 0 }
            let slice = vocab[startIndex..<endIndex]
            let total = slice.count
            let completed = slice.reduce(0) { acc, v in
                acc + (isCompleted(mastery[v.id]) ? 1 : 0)
            }
            return total > 0 ? Double(completed) / Double(total) : 0

        case .seikei:
            let ranges: [(Int, Int)] = [
                (1, 25),
                (26, 50),
                (51, 75),
                (76, 100),
                (101, 125),
                (126, 150),
                (151, 175),
                (176, 200)
            ]
            guard (1...ranges.count).contains(chapterId) else { return 0 }
            let (lo, hi) = ranges[chapterId - 1]

            let vocab = VocabularyData.shared.getVocabulary(for: subject)
            let slice = vocab.filter { v in
                if let n = Int(v.id) {
                    return (lo...hi).contains(n)
                }
                if let n = Int(v.term.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "条", with: "")) {
                    return (lo...hi).contains(n)
                }
                return false
            }
            let total = slice.count
            let completed = slice.reduce(0) { acc, v in
                acc + (isCompleted(mastery[v.id]) ? 1 : 0)
            }
            return total > 0 ? Double(completed) / Double(total) : 0
        }
    }
}
