import SwiftUI

struct WeakWordsView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker

    @ObservedObject private var theme = ThemeManager.shared

    @State private var searchText: String = ""

    private let subjects: [Subject] = [.english, .eiken, .kobun, .kanbun, .seikei]

    var body: some View {
        List {
            ForEach(subjects) { subject in
                let weakItems = weakItems(for: subject)

                Section {
                    NavigationLink(destination: QuizView(subject: subject, chapter: nil, mistakesOnly: true)) {
                        HStack {
                            Image(systemName: subject.icon)
                                .foregroundStyle(subject.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subject.displayName)
                                    .font(.headline)
                                Text("苦手: \(weakItems.count)語")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .disabled(weakItems.isEmpty)

                    if !weakItems.isEmpty {
                        ForEach(filtered(weakItems), id: \.self) { wordId in
                            let item = masteryTracker.items[subject.rawValue]?[wordId]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayText(subject: subject, wordId: wordId).term)
                                    .font(.subheadline)
                                Text(displayText(subject: subject, wordId: wordId).meaning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let chosen = item?.lastChosenAnswerText,
                                   let correct = item?.lastCorrectAnswerText,
                                   item?.lastAnswerWasCorrect == false {
                                    Text("あなた: \(chosen) / 正解: \(correct)")
                                        .font(.caption2)
                                        .foregroundStyle(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
                                }
                            }
                        }
                    }
                } header: {
                    Text(subject.displayName)
                }
            }
        }
        .navigationTitle("苦手一括復習")
        .searchable(text: $searchText, prompt: "検索")
    }

    private func weakItems(for subject: Subject) -> [String] {
        let data = masteryTracker.items[subject.rawValue] ?? [:]
        return data
            .filter { $0.value.mastery == .weak }
            .map { $0.key }
    }

    private func filtered(_ ids: [String]) -> [String] {
        guard !searchText.isEmpty else { return ids }
        let q = searchText.localizedLowercase
        return ids.filter { id in
            let text = displayTextAny(id: id)
            return text.term.localizedLowercase.contains(q) || text.meaning.localizedLowercase.contains(q)
        }
    }

    private func displayText(subject: Subject, wordId: String) -> (term: String, meaning: String) {
        let vocab = VocabularyData.shared.getVocabulary(for: subject)
        if let found = vocab.first(where: { $0.id == wordId }) {
            return (found.term, found.meaning)
        }
        return (wordId, "")
    }

    private func displayTextAny(id: String) -> (term: String, meaning: String) {
        for subject in subjects {
            let t = displayText(subject: subject, wordId: id)
            if t.term != id || !t.meaning.isEmpty {
                return t
            }
        }
        return (id, "")
    }
}

// Previews removed for SPM
