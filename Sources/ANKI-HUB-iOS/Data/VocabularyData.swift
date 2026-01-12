import Foundation

class VocabularyData: ObservableObject {
    static let shared = VocabularyData()
    
    // Chunk size consistent with Web App
    let chunkSize = 50
    
    // In a real app, these would be loaded from JSON/CSV files or a database.
    // For this native port, we store the data in memory.
    
    private var englishData: [Vocabulary] = []

    private var eikenData: [Vocabulary] = []
    
    private var kobunData: [Vocabulary] = []
    
    private var kanbunData: [Vocabulary] = []
    
    private var seikeiData: [Vocabulary] = []
    
    init() {
        setupData()
    }
    
    func getVocabulary(for subject: Subject) -> [Vocabulary] {
        switch subject {
        case .english: return englishData
        case .eiken: return eikenData
        case .kobun: return kobunData
        case .kanbun: return kanbunData
        case .seikei: return seikeiData
        }
    }
    
    // MARK: - Chapter / Chunk Logic
    
    func getChunkCount(for subject: Subject) -> Int {
        let count = getVocabulary(for: subject).count
        return Int(ceil(Double(count) / Double(chunkSize)))
    }
    
    func getVocabularyForChunk(subject: Subject, chunkIndex: Int) -> [Vocabulary] {
        let vocab = getVocabulary(for: subject)
        let startIndex = chunkIndex * chunkSize
        
        guard startIndex < vocab.count else { return [] }
        
        let endIndex = min(startIndex + chunkSize, vocab.count)
        return Array(vocab[startIndex..<endIndex])
    }
    
    // MARK: - Seikei Specific Logic
    
    func getSeikeiChapters() -> [String] {
        let uniqueCategories = Set(seikeiData.compactMap { $0.category })
        // Sort effectively (assuming format like "Chapter 1", "Chapter 2" etc, simple string sort might be okay for now)
        return Array(uniqueCategories).sorted()
    }
    
    func getVocabulary(for subject: Subject, chapter: String?) -> [Vocabulary] {
        let all = getVocabulary(for: subject)
        guard let chapter = chapter, subject == .seikei else { return all }
        
        return all.filter { $0.category == chapter }
    }
    
    private func setupData() {
        // Helper function to load resource from multiple bundle sources
        func loadResource(name: String, ext: String) -> String? {
            var bundles: [Bundle] = [.main]
            #if SWIFT_PACKAGE
            bundles.append(.module)
            #endif
            
            for bundle in bundles {
                if let url = bundle.url(forResource: name, withExtension: ext),
                   let content = try? String(contentsOf: url, encoding: .utf8) {
                    print("✅ Loaded \(name).\(ext) from bundle")
                    return content
                }
            }
            print("⚠️ Could not load \(name).\(ext) from any bundle")
            return nil
        }
        
        // 1. English Data (TSV) from vocab1900.tsv
        if let content = loadResource(name: "vocab1900", ext: "tsv") {
            englishData = DataParser.shared.parseVocab1900TSV(content)
            print("📚 English: \(englishData.count) words loaded")
        } else {
            englishData = []
            print("⚠️ English: vocab1900.tsv not found in Resources. Sample (RawData) fallback is disabled.")
        }

        eikenData = englishData
        
        // 2. Kanbun Data (JSON) from kanbun.json
        struct KanbunItem: Codable {
            let id: String
            let word: String
            let meaning: String
            let reading: String?
            let hint: String?
            let explanation: String?
        }
        
        if let content = loadResource(name: "kanbun", ext: "json"),
           let items = DataParser.shared.parseJSONData(content, type: [KanbunItem].self) {
            kanbunData = items.map { item in
                Vocabulary(
                    id: item.id,
                    term: item.word,
                    meaning: item.meaning,
                    reading: item.reading,
                    hint: item.hint,
                    explanation: item.explanation
                )
            }
            print("📚 Kanbun: \(kanbunData.count) words loaded")
        } else {
            kanbunData = []
            print("⚠️ Kanbun: kanbun.json not found/parse failed. Sample (RawData) fallback is disabled.")
        }
        
        // 3. Kobun Data (JSON) from kobun.json
        struct KobunItem: Codable {
            let id: Int
            let word: String
            let meaning: String
            let hint: String?
            let example: String?
        }

        let baseKobunItems: [KobunItem] = {
            if let baseContent = loadResource(name: "kobun", ext: "json"),
                let parsed = DataParser.shared.parseJSONData(baseContent, type: [KobunItem].self)
            {
                return parsed
            }
            return []
        }()

        let normalizeKobunKey: (String) -> String = { raw in
            raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{3000}", with: "")
        }

        let baseByWordKey: [String: KobunItem] = Dictionary(
            baseKobunItems.map { (normalizeKobunKey($0.word), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var mergedKobunItems: [KobunItem] = baseKobunItems

        if let pdfContent = loadResource(name: "kobun_pdf", ext: "json"),
            let pdfItems = DataParser.shared.parseJSONData(pdfContent, type: [KobunItem].self),
            !pdfItems.isEmpty
        {
            let pdfByWordKey: [String: KobunItem] = Dictionary(
                pdfItems.map { (normalizeKobunKey($0.word), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            for item in pdfItems {
                let key = normalizeKobunKey(item.word)
                if baseByWordKey[key] == nil {
                    mergedKobunItems.append(item)
                }
            }
            kobunData = mergedKobunItems.map { item in
                let key = normalizeKobunKey(item.word)
                let isPdfOnly = baseByWordKey[key] == nil
                let pdf = pdfByWordKey[key]

                let mergedHint: String? = {
                    if let h = item.hint, !h.isEmpty { return h }
                    if !isPdfOnly, let h = pdf?.hint, !h.isEmpty { return h }
                    return nil
                }()
                return Vocabulary(
                    id: isPdfOnly ? "pdf-\(item.id)" : String(item.id),
                    term: item.word,
                    meaning: item.meaning,
                    reading: nil,
                    hint: mergedHint,
                    example: item.example
                )
            }
            print("📚 Kobun: \(kobunData.count) words loaded")
        } else if !baseKobunItems.isEmpty {
            kobunData = baseKobunItems.map { item in
                Vocabulary(
                    id: String(item.id),
                    term: item.word,
                    meaning: item.meaning,
                    reading: nil,
                    hint: item.hint,
                    example: item.example
                )
            }
            print("📚 Kobun: \(kobunData.count) words loaded")
        } else {
            kobunData = []
            print("⚠️ Kobun: kobun_pdf.json/kobun.json not found/parse failed. Sample (RawData) fallback is disabled.")
        }
        
        // 4. Seikei Data (Constitution JSON) from constitution.json
        if let content = loadResource(name: "constitution", ext: "json") {
            seikeiData = DataParser.shared.parseConstitutionData(content)
            if seikeiData.isEmpty {
                print("⚠️ Seikei: constitution.json parsed but produced 0 items. Sample (RawData) fallback is disabled.")
            }
            print("📚 Seikei: \(seikeiData.count) items loaded")
        } else {
            seikeiData = []
            print("⚠️ Seikei: constitution.json not found in Resources. Sample (RawData) fallback is disabled.")
        }
    }
}

