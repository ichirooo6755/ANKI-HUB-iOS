import SwiftUI

struct DueReviewView: View {
    @EnvironmentObject var masteryTracker: MasteryTracker

    private let subjects: [Subject] = [.english, .kobun, .kanbun, .seikei]

    var body: some View {
        List {
            ForEach(subjects) { subject in
                let due = dueItems(for: subject)

                Section {
                    NavigationLink(destination: QuizView(subject: subject, chapter: nil, mistakesOnly: false, dueOnly: true)) {
                        HStack {
                            Image(systemName: subject.icon)
                                .foregroundStyle(subject.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subject.displayName)
                                    .font(.headline)
                                Text("復習待ち: \(due.count)語")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .disabled(due.isEmpty)

                    if !due.isEmpty {
                        ForEach(due.prefix(10), id: \.self) { wordId in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayText(subject: subject, wordId: wordId).term)
                                    .font(.subheadline)
                                Text(displayText(subject: subject, wordId: wordId).meaning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(subject.displayName)
                }
            }
        }
        .navigationTitle("復習待ち")
    }

    private func dueItems(for subject: Subject) -> [String] {
        let vocab = VocabularyData.shared.getVocabulary(for: subject)
        let candidates = masteryTracker.getReviewCandidates(allItems: vocab, subject: subject.rawValue, includeDueSoon: true)
        return candidates.map { $0.id }
    }

    private func displayText(subject: Subject, wordId: String) -> (term: String, meaning: String) {
        let vocab = VocabularyData.shared.getVocabulary(for: subject)
        if let found = vocab.first(where: { $0.id == wordId }) {
            return (found.term, found.meaning)
        }
        return (wordId, "")
    }
}
