import SwiftUI
import VisionKit

struct QuizCaptureView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var recognizedText: String = ""
    @State private var isScanning: Bool = false
    @State private var extractedWords: [ExtractedWord] = []
    @State private var showResults: Bool = false
    
    struct ExtractedWord: Identifiable {
        let id = UUID()
        let term: String
        let meaning: String
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if showResults {
                    resultsView
                } else {
                    scanInputView
                }
            }
            .navigationTitle("クイズキャプチャ")
        }
    }
    
    // MARK: - Scan Input View
    
    private var scanInputView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "camera.viewfinder")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
            
            Text("写真から単語を抽出")
                .font(.title2.bold())
            
            Text("教科書や参考書の写真を撮影すると、\n自動で単語を抽出してクイズを作成します")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Manual Text Input (for demo)
            VStack(alignment: .leading, spacing: 8) {
                Text("テキストを貼り付け")
                    .font(.headline)
                
                TextEditor(text: $recognizedText)
                    .frame(height: 120)
                    .padding(8)
                    .background(theme.currentPalette.color(.border, isDark: theme.effectiveIsDark).opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button {
                    startCameraCapture()
                } label: {
                    Label("カメラ", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                        .foregroundStyle(
                            theme.onColor(for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    extractWordsFromText()
                } label: {
                    Label("抽出", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark))
                        .foregroundStyle(
                            theme.onColor(for: theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("抽出結果")
                    .font(.headline)
                Spacer()
                Button("戻る") {
                    showResults = false
                    extractedWords = []
                }
            }
            .padding(.horizontal)
            
            if extractedWords.isEmpty {
                ContentUnavailableView(
                    "単語が見つかりません",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("テキストから単語を抽出できませんでした")
                )
            } else {
                List(extractedWords) { word in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(word.term)
                                .font(.headline)
                            Text(word.meaning)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark))
                    }
                }
                .listStyle(.plain)
                
                Button {
                    addToWordbook()
                } label: {
                    Label("単語帳に追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                        .foregroundStyle(
                            theme.onColor(for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Functions
    
    private func startCameraCapture() {
        // In production, use VNDocumentCameraViewController
        // For demo, show alert
        isScanning = true
        
        // Simulate camera capture with sample text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            recognizedText = """
            apple: りんご
            book: 本
            computer: コンピュータ
            dictionary: 辞書
            education: 教育
            """
            isScanning = false
            extractWordsFromText()
        }
    }
    
    private func extractWordsFromText() {
        extractedWords = []
        
        // Parse text for word pairs
        let lines = recognizedText.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Try different separators
            var term = ""
            var meaning = ""
            
            if trimmed.contains(": ") {
                let parts = trimmed.components(separatedBy: ": ")
                if parts.count >= 2 {
                    term = parts[0]
                    meaning = parts[1]
                }
            } else if trimmed.contains(" - ") {
                let parts = trimmed.components(separatedBy: " - ")
                if parts.count >= 2 {
                    term = parts[0]
                    meaning = parts[1]
                }
            } else if trimmed.contains("\t") {
                let parts = trimmed.components(separatedBy: "\t")
                if parts.count >= 2 {
                    term = parts[0]
                    meaning = parts[1]
                }
            }
            
            if !term.isEmpty && !meaning.isEmpty {
                extractedWords.append(ExtractedWord(term: term, meaning: meaning))
            }
        }
        
        showResults = true
    }
    
    private func addToWordbook() {
        // Load existing wordbook
        var words: [WordbookEntry] = []
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) {
            words = decoded
        }
        
        let source = "クイズキャプチャ"

        // Add extracted words
        for extracted in extractedWords {
            let entry = WordbookEntry(
                id: UUID().uuidString,
                term: extracted.term,
                meaning: extracted.meaning,
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
        
        // Reset
        extractedWords = []
        recognizedText = ""
        showResults = false
    }
}

// Previews removed for SPM
