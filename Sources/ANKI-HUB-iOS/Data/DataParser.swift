import Foundation

class DataParser {
    static let shared = DataParser()
    
    private init() {}
    
    /// Parses TSV data for English vocabulary (vocab1900-data.js format)
    func parseVocab1900TSV(_ tsvString: String) -> [Vocabulary] {
        var items: [Vocabulary] = []
        let lines = tsvString.components(separatedBy: .newlines)
        
        for line in lines {
            let components = line.components(separatedBy: "\t")
            if components.count >= 3 {
                let id = components[0].trimmingCharacters(in: .whitespaces)
                let term = components[1].trimmingCharacters(in: .whitespaces)
                let meaning = components[2].trimmingCharacters(in: .whitespaces)
                
                if !id.isEmpty && !term.isEmpty {
                    items.append(Vocabulary(id: id, term: term, meaning: meaning))
                }
            }
        }
        return items
    }
    
    /// Parses JSON data for Kanbun and Kobun
    func parseJSONData<T: Decodable>(_ jsonString: String, type: T.Type) -> T? {
        guard let data = jsonString.data(using: .utf8) else {
            print("Failed to convert string to data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("JSON Parsing Error: \(error)")
            return nil
        }
    }
    
    /// Parses Constitution data and generates Seikei questions
    /// Handles 【...】 as blanks and article numbers
    func parseConstitutionData(_ jsonString: String) -> [Vocabulary] {
        struct Article: Codable {
            let id: String
            let source: String
            let number: String
            let text: String
        }
        
        guard let articles = parseJSONData(jsonString, type: [Article].self) else { return [] }
        
        var vocabItems: [Vocabulary] = []
        
        for article in articles {
            // Process text to find blanks 【...】
            let fullText = article.text
            let regex = try! NSRegularExpression(pattern: "【(.*?)】", options: [])
            let nsString = fullText as NSString
            let matches = regex.matches(in: fullText, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var allAnswers: [String] = []
            var blankMap: [Int] = []
            
            // Map unique answers to indices
            for match in matches {
                let answer = nsString.substring(with: match.range(at: 1))
                let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if trimmed.contains("回答素材") { continue }
                if trimmed.contains("空欄") { continue }
                if let index = allAnswers.firstIndex(of: trimmed) {
                    blankMap.append(index)
                } else {
                    allAnswers.append(trimmed)
                    blankMap.append(allAnswers.count - 1)
                }
            }
            
            // Determine Category (Chapter)
            let chapter: String
            if let num = Int(article.number) {
                if num <= 25 { chapter = "Chapter 1 (1-25条)" }
                else if num <= 50 { chapter = "Chapter 2 (26-50条)" }
                else if num <= 75 { chapter = "Chapter 3 (51-75条)" }
                else if num <= 100 { chapter = "Chapter 4 (76-100条)" }
                else if num <= 125 { chapter = "Chapter 5 (101-125条)" }
                else if num <= 150 { chapter = "Chapter 6 (126-150条)" }
                else if num <= 175 { chapter = "Chapter 7 (151-175条)" }
                else { chapter = "Chapter 8 (176-200条)" }
            } else {
                // Preamble or other
                chapter = "Chapter 1 (1-25条)" // Preamble goes to Chap 1
            }

            let articleLabel: String = {
                if let _ = Int(article.number) {
                    return "第\(article.number)条"
                }
                return "前文"
            }()
            
            // 1. Create Question for filling blanks (if any blanks exist)
            if !allAnswers.isEmpty {
                var item = Vocabulary(
                    id: article.id,
                    term: articleLabel,
                    meaning: "穴埋め（\(allAnswers.count)箇所）",
                    reading: nil,
                    explanation: "出典: \(article.source)"
                )
                item.fullText = fullText
                item.allAnswers = allAnswers
                item.blankMap = blankMap
                item.questionType = "blank"
                item.category = chapter // Set Category
                vocabItems.append(item)
            }
            
            // 2. Create Question for Article Number
            let numberAnswer: String = {
                if let _ = Int(article.number) {
                    return "第\(article.number)条"
                }
                return "前文"
            }()

            var numberItem = Vocabulary(
                id: "\(article.id)-num",
                term: "この条文は何条？",
                meaning: numberAnswer,
                reading: nil,
                explanation: fullText // Show text as context/explanation
            )

            if let _ = Int(article.number) {
                numberItem.fullText = fullText.replacingOccurrences(of: "第\(article.number)条", with: "第[ ? ]条")
            } else {
                numberItem.fullText = fullText
            }
            numberItem.questionType = "number"
            numberItem.category = chapter // Set Category
            vocabItems.append(numberItem)
        }
        
        return vocabItems
    }
    
    /// Parses Nengou data and generates Seikei questions
    /// Handles 【...】 as blanks similar to constitution data
    func parseNengouData(_ jsonString: String) -> [Vocabulary] {
        struct NengouItem: Codable {
            let id: String
            let source: String
            let number: String
            let text: String
        }
        
        guard let nengouItems = parseJSONData(jsonString, type: [NengouItem].self) else { return [] }
        
        var vocabItems: [Vocabulary] = []
        
        for item in nengouItems {
            // Process text to find blanks 【...】
            let fullText = item.text
            let regex = try! NSRegularExpression(pattern: "【(.*?)】", options: [])
            let nsString = fullText as NSString
            let matches = regex.matches(in: fullText, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var allAnswers: [String] = []
            var blankMap: [Int] = []
            
            // Map unique answers to indices
            for match in matches {
                let answer = nsString.substring(with: match.range(at: 1))
                let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if trimmed.contains("回答素材") { continue }
                if trimmed.contains("空欄") { continue }
                if let index = allAnswers.firstIndex(of: trimmed) {
                    blankMap.append(index)
                } else {
                    allAnswers.append(trimmed)
                    blankMap.append(allAnswers.count - 1)
                }
            }
            
            // Determine Category (Chapter) - All nengou items go to Chapter 9
            let chapter = "Chapter 9 (年号)"
            
            // 1. Create Question for filling blanks (if any blanks exist)
            if !allAnswers.isEmpty {
                var vocabItem = Vocabulary(
                    id: item.id,
                    term: "年号 \(item.number)",
                    meaning: "穴埋め（\(allAnswers.count)箇所）",
                    reading: nil,
                    explanation: "出典: \(item.source)"
                )
                vocabItem.fullText = fullText
                vocabItem.allAnswers = allAnswers
                vocabItem.blankMap = blankMap
                vocabItem.questionType = "blank"
                vocabItem.category = chapter
                vocabItems.append(vocabItem)
            }
            
            // 2. Create Question for identifying the era name
            var eraItem = Vocabulary(
                id: "\(item.id)-era",
                term: "この出来事はどの年号の時代？",
                meaning: extractEraName(from: fullText),
                reading: nil,
                explanation: fullText
            )
            
            // Create fullText with blank for era name
            eraItem.fullText = fullText.replacingOccurrences(of: "【(.*?)】", with: "【 ? 】", options: .regularExpression)
            eraItem.questionType = "era"
            eraItem.category = chapter
            vocabItems.append(eraItem)
        }
        
        return vocabItems
    }
    
    /// Helper function to extract era name from text
    private func extractEraName(from text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "【(.*?)】", options: [])
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let answer = nsString.substring(with: match.range(at: 1))
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.contains("回答素材") && !trimmed.contains("空欄") {
                return trimmed
            }
        }
        return "不明"
    }
}
