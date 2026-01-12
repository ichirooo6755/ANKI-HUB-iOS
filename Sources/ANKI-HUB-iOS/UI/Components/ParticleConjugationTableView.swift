import SwiftUI

/// Particle Conjugation Table View for Kobun Quiz
/// Replicates the web app's setupParticleConjugationQuiz function
struct ParticleConjugationTableView: View {
    let particleData: ParticleData
    let blankTarget: BlankTarget
    let choices: [String]
    let correctAnswerIndex: Int
    var onAnswer: (Bool) -> Void

    @ObservedObject private var theme = ThemeManager.shared
    
    @State private var selectedIndex: Int? = nil
    @State private var showResult: Bool = false
    
    enum BlankTarget: String {
        case meaning = "意味"
        case connection = "接続"
        case musubi = "結び"
    }
    
    // Extracted table data
    private var tableData: (type: String, particle: String, meaning: String, connection: String, musubi: String) {
        var connection = "―"
        if let desc = particleData.conjugations?.desc {
            // Extract 接続 from description
            if let match = desc.range(of: "接続[：:]?\\s*(.+)", options: .regularExpression) {
                let extracted = String(desc[match])
                    .replacingOccurrences(of: "接続", with: "")
                    .replacingOccurrences(of: "：", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                connection = extracted.isEmpty ? "―" : extracted
            }
        }
        
        var musubi = "―"
        if particleData.type == "係助詞", let forms = particleData.conjugations?.forms, let firstForm = forms.first {
            if firstForm.contains("連体形") {
                musubi = "連体形"
            } else if firstForm.contains("已然形") {
                musubi = "已然形"
            }
        }
        
        return (particleData.type, particleData.particle, particleData.meaning, connection, musubi)
    }
    
    var body: some View {
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let weak = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)

        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("助詞活用表 穴埋め")
                    .font(.subheadline)
                    .foregroundStyle(primary)
                    .fontWeight(.medium)
                
                Text("「\(blankTarget.rawValue)」を選んでください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Table
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    tableCell("種類", isHeader: true)
                    tableCell("助詞", isHeader: true)
                    tableCell("意味", isHeader: true)
                    tableCell("接続", isHeader: true)
                    if tableData.musubi != "―" || blankTarget == .musubi {
                        tableCell("結び", isHeader: true)
                    }
                }
                
                // Data Row
                HStack(spacing: 0) {
                    tableCell(tableData.type)
                    tableCell(tableData.particle)
                    tableCell(blankTarget == .meaning ? nil : tableData.meaning, isBlank: blankTarget == .meaning, revealed: showResult ? choices[correctAnswerIndex] : nil)
                    tableCell(blankTarget == .connection ? nil : tableData.connection, isBlank: blankTarget == .connection, revealed: showResult ? choices[correctAnswerIndex] : nil)
                    if tableData.musubi != "―" || blankTarget == .musubi {
                        tableCell(blankTarget == .musubi ? nil : tableData.musubi, isBlank: blankTarget == .musubi, revealed: showResult ? choices[correctAnswerIndex] : nil)
                    }
                }
            }
            .background(surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(border.opacity(0.8), lineWidth: 1)
            )
            .padding(.horizontal)
            
            // Choices
            VStack(spacing: 12) {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        guard !showResult else { return }
                        selectedIndex = index
                        showResult = true
                        onAnswer(index == correctAnswerIndex)
                    } label: {
                        HStack {
                            Text(choice)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            
                            if showResult {
                                if index == correctAnswerIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(mastered)
                                } else if index == selectedIndex && index != correctAnswerIndex {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(weak)
                                }
                            }
                        }
                        .padding()
                        .background(choiceBackground(index: index))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(choiceBorder(index: index), lineWidth: 2)
                        )
                    }
                    .disabled(showResult)
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func tableCell(_ content: String? = nil, isHeader: Bool = false, isBlank: Bool = false, revealed: String? = nil) -> some View {
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        ZStack {
            if isHeader {
                Text(content ?? "")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            } else if isBlank {
                if let revealed = revealed {
                    Text(revealed)
                        .font(.subheadline.bold())
                        .foregroundStyle(mastered)
                } else {
                    Text("？")
                        .font(.subheadline.bold())
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } else {
                Text(content ?? "")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(isHeader ? border.opacity(0.2) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(border.opacity(0.35), lineWidth: 0.5)
        )
    }
    
    private func choiceBackground(index: Int) -> Color {
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let weak = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        if !showResult {
            return surface.opacity(0.6)
        }
        if index == correctAnswerIndex {
            return mastered.opacity(0.2)
        }
        if index == selectedIndex && index != correctAnswerIndex {
            return weak.opacity(0.2)
        }
        return surface.opacity(0.6)
    }
    
    private func choiceBorder(index: Int) -> Color {
        let mastered = theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
        let weak = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        if !showResult {
            return Color.clear
        }
        if index == correctAnswerIndex {
            return mastered
        }
        if index == selectedIndex && index != correctAnswerIndex {
            return weak
        }
        return Color.clear
    }
}

// MARK: - Helper to generate particle quiz questions

struct ParticleQuizGenerator {
    static let connectionOptions = [
        "未然形", "連用形", "終止形", "連体形", "已然形", "命令形",
        "未然形・已然形", "連用形・終止形", "体言", "体言・連体形"
    ]
    
    static let musubiOptions = [
        "未然形", "連用形", "終止形", "連体形", "已然形", "命令形"
    ]
    
    static func generateQuestion(
        from particle: ParticleData,
        allParticles: [ParticleData]
    ) -> (blankTarget: ParticleConjugationTableView.BlankTarget, choices: [String], correctIndex: Int)? {
        
        // Determine available blank targets
        var targets: [ParticleConjugationTableView.BlankTarget] = [.meaning, .connection]
        if particle.type == "係助詞" {
            targets.append(.musubi)
        }
        
        guard let target = targets.randomElement() else { return nil }
        
        // Get correct answer
        let correctAnswer: String
        switch target {
        case .meaning:
            correctAnswer = particle.meaning
        case .connection:
            if let desc = particle.conjugations?.desc {
                let match = desc.replacingOccurrences(of: "接続", with: "")
                    .replacingOccurrences(of: "：", with: "").replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                correctAnswer = match.isEmpty ? "―" : match
            } else {
                correctAnswer = "―"
            }
        case .musubi:
            if let forms = particle.conjugations?.forms, let first = forms.first {
                if first.contains("連体形") { correctAnswer = "連体形" }
                else if first.contains("已然形") { correctAnswer = "已然形" }
                else { correctAnswer = "―" }
            } else {
                correctAnswer = "―"
            }
        }
        
        // Generate wrong answers
        var wrongAnswers: [String] = []
        switch target {
        case .meaning:
            wrongAnswers = allParticles
                .filter { $0.id != particle.id }
                .map { $0.meaning }
                .shuffled()
                .prefix(3)
                .map { $0 }
        case .connection:
            wrongAnswers = connectionOptions
                .filter { $0 != correctAnswer }
                .shuffled()
                .prefix(3)
                .map { $0 }
        case .musubi:
            wrongAnswers = musubiOptions
                .filter { $0 != correctAnswer }
                .shuffled()
                .prefix(3)
                .map { $0 }
        }
        
        // Shuffle choices
        var choices = [correctAnswer] + wrongAnswers
        choices.shuffle()
        
        let correctIndex = choices.firstIndex(of: correctAnswer) ?? 0
        
        return (target, choices, correctIndex)
    }
}
