import Foundation

/// 3アマ（ham3）の仮想チャプター名
enum Ham3ChapterOption {
    static let all = "すべて"
    static let regulationAll = "法規すべて"
    static let engineeringAll = "工学すべて"

    static func isVirtualAggregate(_ chapter: String) -> Bool {
        chapter == all
            || chapter == regulationAll
            || chapter == engineeringAll
    }

    static func description(for chapter: String) -> String {
        switch chapter {
        case all: return "法規・工学の全問題"
        case regulationAll: return "法規問題すべて"
        case engineeringAll: return "工学問題すべて"
        default:
            if chapter.hasPrefix("法規") { return "法規問題" }
            if chapter.hasPrefix("工学") { return "工学問題" }
            return chapter
        }
    }

    static func examChaptersOnly(from options: [String]) -> [String] {
        options.filter { !isVirtualAggregate($0) }
    }
}

struct Ham3ChapterSection: Identifiable {
    let id: String
    let title: String
    let chapters: [String]
}

class VocabularyData: ObservableObject {
    static let shared = VocabularyData()
    
    // Chunk size consistent with Web App
    let chunkSize = 50
    
    // In a real app, these would be loaded from JSON/CSV files or a database.
    // For this native port, we store the data in memory.
    
    private var englishData: [Vocabulary] = []
    
    private var kobunData: [Vocabulary] = []
    
    private var kanbunData: [Vocabulary] = []
    
    private var seikeiData: [Vocabulary] = []
    
    private var ham3Data: [Vocabulary] = []
    private var accountingData: [Vocabulary] = []
    private var manefiData: [Vocabulary] = []

    private var particlesData: [ParticleData] = []

    init() {
        setupData()
    }
    
    func getVocabulary(for subject: Subject) -> [Vocabulary] {
        switch subject {
        case .english: return englishData
        case .kobun: return kobunData
        case .kanbun: return kanbunData
        case .seikei: return seikeiData
        case .ham3: return ham3Data
        case .accounting: return accountingData
        case .manefi: return manefiData
        }
    }

    func getParticles() -> [ParticleData] {
        particlesData
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

    func getHam3Chapters() -> [String] {
        let uniqueCategories = Set(ham3Data.compactMap { $0.category })
        return Array(uniqueCategories).sorted { lhs, rhs in
            ham3ChapterSortKey(lhs) < ham3ChapterSortKey(rhs)
        }
    }

    /// クイズ設定・チャプター一覧用（すべて / 法規・工学グループ / 各回）
    func getHam3ChapterOptions() -> [String] {
        let examChapters = getHam3Chapters()
        let regulation = examChapters.filter { ($0).hasPrefix("法規") }
        let engineering = examChapters.filter { ($0).hasPrefix("工学") }

        var options: [String] = [
            Ham3ChapterOption.all,
            Ham3ChapterOption.regulationAll,
        ]
        options.append(contentsOf: regulation)
        options.append(Ham3ChapterOption.engineeringAll)
        options.append(contentsOf: engineering)
        return options
    }

    func getHam3ChapterSections() -> [Ham3ChapterSection] {
        let examChapters = getHam3Chapters()
        let regulation = examChapters.filter { $0.hasPrefix("法規") }
        let engineering = examChapters.filter { $0.hasPrefix("工学") }

        let regulationChapters = [Ham3ChapterOption.regulationAll] + regulation
        let engineeringChapters = [Ham3ChapterOption.engineeringAll] + engineering

        return [
            Ham3ChapterSection(id: "all", title: "全体", chapters: [Ham3ChapterOption.all]),
            Ham3ChapterSection(id: "regulation", title: "法規", chapters: regulationChapters),
            Ham3ChapterSection(id: "engineering", title: "工学", chapters: engineeringChapters),
        ]
    }

    /// カテゴリのみで絞り込み（間違いのみは QuizView のトグルで適用）
    func filterHam3Vocabulary(_ vocab: [Vocabulary], chapter: String) -> [Vocabulary] {
        if chapter == Ham3ChapterOption.all {
            return vocab
        }
        switch chapter {
        case Ham3ChapterOption.regulationAll:
            return vocab.filter { ($0.category ?? "").hasPrefix("法規") }
        case Ham3ChapterOption.engineeringAll:
            return vocab.filter { ($0.category ?? "").hasPrefix("工学") }
        default:
            return vocab.filter { $0.category == chapter }
        }
    }

    private func ham3ChapterSortKey(_ chapter: String) -> (Int, Int) {
        let isRegulation = chapter.hasPrefix("法規") ? 0 : 1
        let digits = chapter.filter(\.isNumber)
        let number = Int(digits) ?? 0
        return (isRegulation, number)
    }
    
    func getVocabulary(for subject: Subject, chapter: String?) -> [Vocabulary] {
        let all = getVocabulary(for: subject)
        guard let chapter = chapter else { return all }
        switch subject {
        case .seikei:
            return all.filter { $0.category == chapter }
        case .ham3:
            return all.filter { $0.category == chapter }
        case .accounting, .manefi:
            return all.filter { $0.category == chapter }
        default:
            return all
        }
    }

    func getCategoryChapters(for subject: Subject) -> [String] {
        let unique = Set(getVocabulary(for: subject).compactMap { $0.category }.filter { !$0.isEmpty })
        // マネファイ: A（公式穴埋め）→ C（計算公式集中暗記）→ 先生（教材・試験）→ AI（補強）の順。その他は辞書順。
        return Array(unique).sorted { a, b in
            func rank(_ s: String) -> Int {
                if s.hasPrefix("A・") || s == "A" { return -2 }
                if DataParser.isFormulaMemorizationCategory(s) { return -1 }
                if s.hasPrefix("先生") { return 0 }
                if s.hasPrefix("AI") { return 1 }
                return 2
            }
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return a < b
        }
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
        
        // 2. Kanbun Data (JSON) from kanbun.json
        struct KanbunItem: Codable {
            let id: String
            let word: String
            let meaning: String
            let reading: String?
            let hint: String?
            let explanation: String?
            let example: String?
        }
        
        var baseKanbunItems: [Vocabulary] = []
        if let content = loadResource(name: "kanbun", ext: "json"),
           let items = DataParser.shared.parseJSONData(content, type: [KanbunItem].self) {
            baseKanbunItems = items.map { item in
                Vocabulary(
                    id: item.id,
                    term: item.word,
                    meaning: item.meaning,
                    reading: item.reading,
                    hint: item.hint,
                    example: item.example,
                    explanation: item.explanation
                )
            }
            print("📚 Kanbun: \(baseKanbunItems.count) words loaded")
        } else {
            print("⚠️ Kanbun: kanbun.json not found/parse failed. Sample (RawData) fallback is disabled.")
        }

        var grammarKanbunItems: [Vocabulary] = []
        if let content = loadResource(name: "kanbun_grammar", ext: "json"),
           let items = DataParser.shared.parseJSONData(content, type: [KanbunItem].self) {
            grammarKanbunItems = items.map { item in
                Vocabulary(
                    id: item.id,
                    term: item.word,
                    meaning: item.meaning,
                    reading: item.reading,
                    hint: item.hint,
                    example: item.example,
                    explanation: item.explanation
                )
            }
            print("📚 Kanbun Grammar: \(grammarKanbunItems.count) items loaded")
        }

        kanbunData = baseKanbunItems + grammarKanbunItems
        if kanbunData.isEmpty {
            print("⚠️ Kanbun: no items loaded")
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
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            s = s.replacingOccurrences(of: "\u{3000}", with: "")
            s = s.replacingOccurrences(of: " ", with: "")
            s = s.replacingOccurrences(of: "（[^）]*）", with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: "\\([^\\)]*\\)", with: "", options: .regularExpression)
            return s
        }

        let kobunHintKeys: (String?) -> [String] = { rawHint in
            guard var s = rawHint?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty
            else {
                return []
            }

            s = s.replacingOccurrences(of: "\u{3000}", with: "/")
            s = s.replacingOccurrences(of: " ", with: "/")
            s = s.replacingOccurrences(of: "）", with: "/")
            s = s.replacingOccurrences(of: ")", with: "/")
            s = s.replacingOccurrences(of: "（", with: "")
            s = s.replacingOccurrences(of: "(", with: "")
            s = s.replacingOccurrences(of: "／", with: "/")
            s = s.replacingOccurrences(of: "・", with: "/")
            s = s.replacingOccurrences(of: "、", with: "/")
            s = s.replacingOccurrences(of: ",", with: "/")

            let parts = s.split(whereSeparator: { $0 == "/" }).map(String.init)

            var out: [String] = []
            out.reserveCapacity(parts.count)

            let kanjiRegex = try? NSRegularExpression(pattern: "[\\u4E00-\\u9FFF]", options: [])
            for p in parts {
                let normalized = normalizeKobunKey(p)
                if normalized.isEmpty { continue }
                out.append(normalized)

                if let re = kanjiRegex {
                    let range = NSRange(location: 0, length: normalized.utf16.count)
                    let hasKanji = re.firstMatch(in: normalized, options: [], range: range) != nil
                    if hasKanji {
                        let kanjiOnly = normalized.unicodeScalars.filter { scalar in
                            scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
                        }.map(String.init).joined()

                        let hasNonKanji = kanjiOnly != normalized
                        if hasNonKanji, !kanjiOnly.isEmpty {
                            out.append(kanjiOnly)
                        }
                    }
                }
            }

            return Array(Set(out))
        }

        let kobunKeys: (String) -> [String] = { raw in
            let cleaned = normalizeKobunKey(raw)
            if cleaned.isEmpty { return [] }
            let parts = cleaned.split(whereSeparator: { $0 == "/" || $0 == "／" }).map(String.init)
            let filtered = parts.filter { !$0.isEmpty }

            let baseParts = filtered.isEmpty ? [cleaned] : filtered
            return Array(Set(baseParts))
        }

        let finalizeKobunData: ([KobunItem], Set<String>) -> [Vocabulary] = { items, baseKeys in
            func normalizeForDedupe(_ raw: String) -> String {
                normalizeKobunKey(raw)
            }

            var keyToItem: [String: KobunItem] = [:]
            keyToItem.reserveCapacity(items.count)
            var orderKeys: [String] = []
            orderKeys.reserveCapacity(items.count)

            for item in items {
                let key = normalizeForDedupe(item.word)
                if key.isEmpty { continue }

                if let existing = keyToItem[key] {
                    let merged = KobunItem(
                        id: existing.id,
                        word: existing.word,
                        meaning: existing.meaning.isEmpty ? item.meaning : existing.meaning,
                        hint: (existing.hint?.isEmpty == false) ? existing.hint : item.hint,
                        example: (existing.example?.isEmpty == false) ? existing.example : item.example
                    )
                    keyToItem[key] = merged
                } else {
                    keyToItem[key] = item
                    orderKeys.append(key)
                }
            }

            let sortedKeys = orderKeys.sorted { a, b in
                let ia = keyToItem[a]?.id ?? 0
                let ib = keyToItem[b]?.id ?? 0
                if ia != ib { return ia < ib }
                return a < b
            }

            return sortedKeys.enumerated().compactMap { idx, k in
                guard let item = keyToItem[k] else { return nil }
                let isPdfOnly = !baseKeys.contains(k)
                return Vocabulary(
                    id: isPdfOnly ? "pdf-\(item.id)" : String(item.id),
                    term: item.word,
                    meaning: item.meaning,
                    reading: nil,
                    hint: item.hint,
                    example: item.example
                )
            }
        }

        var mergedKobunItems: [KobunItem] = baseKobunItems

        let baseWordKeys: Set<String> = Set(
            baseKobunItems
                .map { normalizeKobunKey($0.word) }
                .filter { !$0.isEmpty }
        )

        var keyToIndex: [String: Int] = [:]
        if !baseKobunItems.isEmpty {
            for (idx, item) in baseKobunItems.enumerated() {
                for k in kobunKeys(item.word) {
                    if keyToIndex[k] == nil {
                        keyToIndex[k] = idx
                    }
                }
            }

            for (idx, item) in baseKobunItems.enumerated() {
                for k in kobunHintKeys(item.hint) {
                    if keyToIndex[k] == nil {
                        keyToIndex[k] = idx
                    }
                }
            }
        }

        if let pdfContent = loadResource(name: "kobun_pdf", ext: "json"),
            let pdfItems = DataParser.shared.parseJSONData(pdfContent, type: [KobunItem].self),
            !pdfItems.isEmpty
        {
            for pdfItem in pdfItems {
                let keys = kobunKeys(pdfItem.word)
                var matchedIndex: Int?
                for k in keys {
                    if let idx = keyToIndex[k] {
                        matchedIndex = idx
                        break
                    }
                }

                if let idx = matchedIndex {
                    let base = mergedKobunItems[idx]
                    let mergedHint: String? = {
                        if let h = base.hint, !h.isEmpty { return h }
                        if let h = pdfItem.hint, !h.isEmpty { return h }
                        return nil
                    }()
                    let mergedExample: String? = {
                        if let e = base.example, !e.isEmpty { return e }
                        if let e = pdfItem.example, !e.isEmpty { return e }
                        return nil
                    }()
                    let mergedMeaning: String = base.meaning.isEmpty ? pdfItem.meaning : base.meaning

                    if mergedHint != base.hint || mergedExample != base.example || mergedMeaning != base.meaning {
                        mergedKobunItems[idx] = KobunItem(
                            id: base.id,
                            word: base.word,
                            meaning: mergedMeaning,
                            hint: mergedHint,
                            example: mergedExample
                        )
                    }
                } else {
                    let newIndex = mergedKobunItems.count
                    mergedKobunItems.append(pdfItem)
                    for k in keys {
                        if keyToIndex[k] == nil {
                            keyToIndex[k] = newIndex
                        }
                    }
                }
            }

            kobunData = finalizeKobunData(mergedKobunItems, baseWordKeys)
            print("📚 Kobun: \(kobunData.count) words loaded")
        } else if !baseKobunItems.isEmpty {
            kobunData = finalizeKobunData(baseKobunItems, baseWordKeys)
            print("📚 Kobun: \(kobunData.count) words loaded")
        } else {
            kobunData = []
            print("⚠️ Kobun: kobun_pdf.json/kobun.json not found/parse failed. Sample (RawData) fallback is disabled.")
        }
        
        // 4. Seikei Data (Constitution JSON) from constitution.json
        var constitutionItems: [Vocabulary] = []
        if let content = loadResource(name: "constitution", ext: "json") {
            constitutionItems = DataParser.shared.parseConstitutionData(content)
            if constitutionItems.isEmpty {
                print("⚠️ Seikei: constitution.json parsed but produced 0 items.")
            }
            print("📚 Seikei Constitution: \(constitutionItems.count) items loaded")
        } else {
            print("⚠️ Seikei: constitution.json not found in Resources.")
        }
        
        // 5. Nengou Data (JSON) from nengou.json
        var nengouItems: [Vocabulary] = []
        if let content = loadResource(name: "nengou", ext: "json") {
            nengouItems = DataParser.shared.parseNengouData(content)
            if nengouItems.isEmpty {
                print("⚠️ Seikei: nengou.json parsed but produced 0 items.")
            }
            print("📚 Seikei Nengou: \(nengouItems.count) items loaded")
        } else {
            print("⚠️ Seikei: nengou.json not found in Resources.")
        }
        
        // Merge constitution and nengou data
        seikeiData = constitutionItems + nengouItems
        print("📚 Seikei Total: \(seikeiData.count) items loaded")

        // 6. Ham3 Data (3アマ) from ham3.json
        if let content = loadResource(name: "ham3", ext: "json") {
            ham3Data = DataParser.shared.parseHam3Data(content)
            print("📚 Ham3: \(ham3Data.count) questions loaded")
        } else {
            ham3Data = []
            print("⚠️ Ham3: ham3.json not found in Resources.")
        }

        // 7. Accounting
        if let content = loadResource(name: "accounting", ext: "json") {
            accountingData = DataParser.shared.parseMultipleChoiceData(
                content,
                questionType: "accounting",
                sourceLabel: "アカウンティング入門"
            )
            print("📚 Accounting: \(accountingData.count) questions loaded")
        } else {
            accountingData = []
            print("⚠️ Accounting: accounting.json not found in Resources.")
        }

        // 8. Manefi
        if let content = loadResource(name: "manefi", ext: "json") {
            manefiData = DataParser.shared.parseMultipleChoiceData(
                content,
                questionType: "manefi",
                sourceLabel: "マネファイ"
            )
            print("📚 Manefi: \(manefiData.count) questions loaded")
        } else {
            manefiData = []
            print("⚠️ Manefi: manefi.json not found in Resources.")
        }

        if let content = loadResource(name: "particles", ext: "json"),
           let data = content.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ParticleData].self, from: data)
        {
            particlesData = decoded
            print("📚 Kobun Particles: \(particlesData.count) items loaded")
        } else {
            particlesData = []
            print("⚠️ Kobun: particles.json not found in Resources.")
        }
    }
}

