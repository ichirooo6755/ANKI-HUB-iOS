import SwiftUI

/// 紙の単語帳番号入力（ScanView 内タブでも使用）
struct PaperWordbookSyncContent: View {
    @State private var inputNumber: String = ""
    @State private var syncedWords: [SyncedWord] = []
    @State private var showSuccess: Bool = false

    @ObservedObject private var theme = ThemeManager.shared

    struct SyncedWord: Identifiable {
        let id = UUID()
        let number: Int
        let term: String
        let meaning: String
    }

    private var englishIndex: [Int: Vocabulary] {
        let vocab = VocabularyData.shared.getVocabulary(for: .english)
        var dict: [Int: Vocabulary] = [:]
        for v in vocab {
            if let n = Int(v.id) {
                dict[n] = v
            }
        }
        return dict
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "book.pages.fill")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))

                Text("紙の単語帳と同期")
                    .font(.title2.bold())
                    .foregroundStyle(theme.primaryText)

                Text("紙の単語帳の番号を入力すると、\n対応する単語がアプリに取り込まれます")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("番号を入力")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    HStack {
                        TextField("例: 1-10 または 1,2,5", text: $inputNumber)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            #endif

                        Button("同期") {
                            syncWords()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)

                if !syncedWords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("プレビュー (\(syncedWords.count)語)")
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)

                        ForEach(syncedWords) { word in
                            HStack {
                                Text("#\(word.number)")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                    .frame(width: 40, alignment: .leading)
                                VStack(alignment: .leading) {
                                    Text(word.term).font(.headline)
                                    Text(word.meaning).font(.caption).foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            addAllToWordbook()
                        } label: {
                            let bg = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                            Text("単語帳に追加")
                                .font(.headline)
                                .foregroundStyle(theme.onColor(for: bg))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bg, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
        }
        .alert("追加完了", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(syncedWords.count)語を単語帳に追加しました")
        }
    }

    private func syncWords() {
        syncedWords = []
        var numbers: [Int] = []

        if inputNumber.contains("-") {
            let parts = inputNumber.components(separatedBy: "-")
            if parts.count == 2,
               let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let end = Int(parts[1].trimmingCharacters(in: .whitespaces))
            {
                numbers = Array(start...end)
            }
        } else if inputNumber.contains(",") {
            for part in inputNumber.components(separatedBy: ",") {
                if let num = Int(part.trimmingCharacters(in: .whitespaces)) {
                    numbers.append(num)
                }
            }
        } else if let num = Int(inputNumber.trimmingCharacters(in: .whitespaces)) {
            numbers = [num]
        }

        for num in numbers {
            if let v = englishIndex[num] {
                syncedWords.append(SyncedWord(number: num, term: v.term, meaning: v.meaning))
            }
        }
    }

    private func addAllToWordbook() {
        var words: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data)
        {
            words = decoded
        }

        let source = "紙の単語帳"
        for synced in syncedWords {
            let entry = WordbookEntry(
                id: "paper_\(synced.number)",
                term: synced.term,
                meaning: synced.meaning,
                hint: nil,
                source: source,
                mastery: .new
            )
            if !words.contains(where: { $0.term == entry.term }) {
                words.append(entry)
            }
        }

        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
        }
        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
        showSuccess = true
    }
}

/// 後方互換。`ScanView(initialMode: .paper)` へ転送。
struct PaperWordbookSyncView: View {
    var body: some View {
        ScanView(initialMode: .paper)
    }
}
