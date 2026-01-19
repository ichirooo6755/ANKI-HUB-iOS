import SwiftUI

struct PaperWordbookSyncView: View {
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
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                
                Text("紙の単語帳と同期")
                    .font(.title2.bold())
                
                Text("紙の単語帳の番号を入力すると、\n対応する単語がアプリに取り込まれます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Number Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("番号を入力")
                        .font(.headline)
                    
                    HStack {
                        TextField("例: 1-10 または 1,2,5", text: $inputNumber)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            #endif
                        
                        Button {
                            syncWords()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .padding()
                                .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                                .foregroundStyle(
                                    theme.onColor(for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    Text("範囲指定: 1-10 / 複数指定: 1,2,5,7")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                // Synced Words List
                if !syncedWords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("同期済み: \(syncedWords.count)語")
                                .font(.headline)
                            Spacer()
                            Button("単語帳に追加") {
                                addAllToWordbook()
                            }
                            .font(.subheadline)
                            .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(syncedWords) { word in
                                    HStack {
                                        Text("#\(word.number)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 40, alignment: .leading)
                                        Text(word.term)
                                            .font(.headline)
                                        Spacer()
                                        Text(word.meaning)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .liquidGlass()
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("紙の単語帳同期")
            .alert("追加完了", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(syncedWords.count)語を単語帳に追加しました")
            }
        }
    }
    
    private func syncWords() {
        syncedWords = []
        
        // Parse input
        var numbers: [Int] = []
        
        // Handle range (e.g., "1-10")
        if inputNumber.contains("-") {
            let parts = inputNumber.components(separatedBy: "-")
            if parts.count == 2,
               let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let end = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                numbers = Array(start...end)
            }
        }
        // Handle comma-separated (e.g., "1,2,5")
        else if inputNumber.contains(",") {
            let parts = inputNumber.components(separatedBy: ",")
            for part in parts {
                if let num = Int(part.trimmingCharacters(in: .whitespaces)) {
                    numbers.append(num)
                }
            }
        }
        // Single number
        else if let num = Int(inputNumber.trimmingCharacters(in: .whitespaces)) {
            numbers = [num]
        }
        
        // Fetch words
        for num in numbers {
            if let v = englishIndex[num] {
                syncedWords.append(SyncedWord(
                    number: num,
                    term: v.term,
                    meaning: v.meaning
                ))
            }
        }
    }
    
    private func addAllToWordbook() {
        // Load existing wordbook
        var words: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) {
            words = decoded
        }
        
        let source = "紙の単語帳"

        // Add synced words
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
        
        // Save
        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
        }

        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
        
        showSuccess = true
    }
}

// Preview removed for SPM compatibility
