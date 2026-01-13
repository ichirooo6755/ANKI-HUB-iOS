import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct WordbookView: View {
    @State private var words: [WordbookEntry] = []
    @State private var searchText: String = ""
    @State private var showAddSheet: Bool = false
    @State private var filterMastery: MasteryLevel? = nil

    @State private var showCSVExporter: Bool = false
    @State private var showCSVImporter: Bool = false
    @State private var csvDocument: CSVTextDocument = CSVTextDocument()
    @State private var csvErrorMessage: String = ""
    
    @EnvironmentObject var masteryTracker: MasteryTracker
    
    var filteredWords: [WordbookEntry] {
        var result = words
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.term.localizedCaseInsensitiveContains(searchText) ||
                $0.meaning.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let filter = filterMastery {
            result = result.filter { $0.mastery == filter }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("検索...", text: $searchText)
                }
                .padding()
                .liquidGlass()
                .padding()
                
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "すべて", isSelected: filterMastery == nil) {
                            filterMastery = nil
                        }
                        ForEach(MasteryLevel.allCases, id: \.self) { level in
                            FilterPill(title: level.label, color: level.color, isSelected: filterMastery == level) {
                                filterMastery = level
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Word List
                if filteredWords.isEmpty {
                    ContentUnavailableView(
                        "単語がありません",
                        systemImage: "book.closed",
                        description: Text("右上の＋ボタンから単語を追加してください")
                    )
                } else {
                    List {
                        ForEach(filteredWords) { word in
                            WordRow(word: word)
                        }
                        .onDelete(perform: deleteWords)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("単語帳")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("単語を追加", systemImage: "plus")
                        }
                        Button {
                            csvErrorMessage = ""
                            showCSVImporter = true
                        } label: {
                            Label("CSVインポート", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            csvDocument = CSVTextDocument(text: makeCSV())
                            showCSVExporter = true
                        } label: {
                            Label("CSVエクスポート（ファイル）", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            copyCSVToClipboard()
                        } label: {
                            Label("CSVをコピー", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddWordSheet(words: $words)
            }
            .fileExporter(
                isPresented: $showCSVExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "wordbook"
            ) { _ in }
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let data = try Data(contentsOf: url)
                        let text = String(data: data, encoding: .utf8) ?? ""
                        importFromCSVText(text)
                    } catch {
                        csvErrorMessage = "読み込みに失敗しました"
                    }
                case .failure:
                    csvErrorMessage = "読み込みに失敗しました"
                }
            }
            .alert("CSV", isPresented: Binding(get: { !csvErrorMessage.isEmpty }, set: { if !$0 { csvErrorMessage = "" } })) {
                Button("OK") { csvErrorMessage = "" }
            } message: {
                Text(csvErrorMessage)
            }
            .onAppear {
                loadWords()
            }
        }
    }
    
    private func loadWords() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
           let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data) {
            words = decoded
        }
    }
    
    private func saveWords() {
        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
        }

        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
    }
    
    private func deleteWords(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        saveWords()
    }
    
    private func importFromCSVText(_ text: String) {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            csvErrorMessage = "CSVが空です"
            return
        }

        var importedCount = 0

        for line in lines {
            let components = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
            guard components.count >= 2 else { continue }

            let term = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = components.count > 2 ? components[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil

            guard !term.isEmpty, !meaning.isEmpty else { continue }

            let entry = WordbookEntry(
                id: UUID().uuidString,
                term: term,
                meaning: meaning,
                hint: (hint?.isEmpty ?? true) ? nil : hint,
                mastery: .new
            )

            if !words.contains(where: { $0.term == entry.term }) {
                words.append(entry)
                importedCount += 1
            }
        }

        saveWords()
        csvErrorMessage = "\(importedCount)件インポートしました"
    }

    private func makeCSV() -> String {
        var csvContent = ""
        for word in words {
            let hint = word.hint ?? ""
            csvContent += "\(word.term),\(word.meaning),\(hint)\n"
        }
        return csvContent
    }

    private func copyCSVToClipboard() {
        let csvContent = makeCSV()
        #if os(iOS)
        UIPasteboard.general.string = csvContent
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(csvContent, forType: .string)
        #endif
        csvErrorMessage = "CSVをコピーしました"
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct WordRow: View {
    let word: WordbookEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.term)
                    .font(.headline)
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(word.mastery.color)
                .frame(width: 12, height: 12)
        }
        .padding(.vertical, 4)
    }
}

struct AddWordSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var words: [WordbookEntry]
    
    @State private var term: String = ""
    @State private var meaning: String = ""
    @State private var hint: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("単語") {
                    TextField("単語を入力", text: $term)
                    TextField("意味を入力", text: $meaning)
                    TextField("ヒント（任意）", text: $hint)
                }
            }
            .navigationTitle("単語を追加")
            #if os(iOS)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let newWord = WordbookEntry(
                            id: UUID().uuidString,
                            term: term,
                            meaning: meaning,
                            hint: hint.isEmpty ? nil : hint,
                            mastery: .new
                        )
                        words.append(newWord)
                        saveWords()
                        dismiss()
                    }
                    .disabled(term.isEmpty || meaning.isEmpty)
                }
            }
        }
    }
    
    private func saveWords() {
        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
        }

        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
    }
}

// Previews removed for SPM
