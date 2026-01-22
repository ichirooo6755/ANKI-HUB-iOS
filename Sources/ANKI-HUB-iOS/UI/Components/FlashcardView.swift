import SwiftUI

struct FlashcardView: View {
    let vocabulary: Vocabulary
    let subject: Subject
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var offset: CGSize = .zero
    @Binding var isFlipped: Bool
    var isRedSheetEnabled: Bool = false
    var showsHintOnFront: Bool = true
    var showsHintOnBack: Bool = false
    var showsReadingOnBack: Bool = true
    @State private var color: Color = .clear
    
    // Seikei State
    @State private var revealedId: Int?
    
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void
    var onBookmark: (() -> Void)? = nil
    var isBookmarked: Bool = false
    
    var body: some View {
        ZStack {
            // Background Card (for stack effect, optional)
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(radius: 4)
                .offset(x: 0, y: 4)
                .scaleEffect(0.95)
            
            // Main Card
            ZStack {
                // Back (Answer)

                if subject == .seikei {
                    // Seikei: Use fullText with parsed blanks
                    let (seikeiContent, seikeiBlankMap) = parseSeikeiContent(vocabulary)
                    Group {
                        SeikeiWebView(content: seikeiContent, blankMap: seikeiBlankMap, revealedId: $revealedId, isAllRevealed: true) { id, ans in
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(reduceMotion ? .zero : .degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    let backSubtextParts = [
                        showsHintOnBack ? (vocabulary.hint ?? "") : "",
                        showsReadingOnBack ? (vocabulary.reading ?? "") : "",
                    ].filter { !$0.isEmpty }
                    let backSubtext = backSubtextParts.joined(separator: "\n")
                    CardContent(
                        text: vocabulary.meaning,
                        subtext: backSubtext,
                        isFront: false,
                        isRedSheet: isRedSheetEnabled
                    )
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(reduceMotion ? .zero : .degrees(180), axis: (x: 0, y: 1, z: 0))
                }
                
                // Front (Question)
                if subject == .seikei {
                    let (seikeiContent, seikeiBlankMap) = parseSeikeiContent(vocabulary)
                    Group {
                        SeikeiWebView(content: seikeiContent, blankMap: seikeiBlankMap, revealedId: $revealedId, isAllRevealed: false) { id, ans in
                            // On tap blank
                            revealedId = id
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .opacity(isFlipped ? 0 : 1)
                } else {
                    CardContent(
                        text: vocabulary.term,
                        subtext: showsHintOnFront ? (vocabulary.hint ?? "") : "",
                        isFront: true
                    )
                        .opacity(isFlipped ? 0 : 1)
                }

                // Bookmark Button Overlay
                VStack {
                    HStack {
                        Spacer()
                        if let onBookmark {
                            Button {
                                onBookmark()
                            } label: {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(
                                        theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                                    )
                                    .padding(4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 400)
            .liquidGlass(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color, lineWidth: 4)
            )
            .rotation3DEffect(reduceMotion ? .zero : .degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .offset(x: offset.width, y: 0)
            .rotationEffect(reduceMotion ? .zero : .degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !reduceMotion {
                            offset = gesture.translation
                            if offset.width > 0 {
                                color = .green.opacity(0.6)
                            } else {
                                color = .red.opacity(0.6)
                            }
                        }
                    }
                    .onEnded { gesture in
                        if reduceMotion {
                            let width = gesture.translation.width
                            if width > 100 {
                                onSwipeRight()
                            } else if width < -100 {
                                onSwipeLeft()
                            }
                            offset = .zero
                            color = .clear
                        } else {
                            withAnimation {
                                if offset.width > 100 {
                                    onSwipeRight()
                                } else if offset.width < -100 {
                                    onSwipeLeft()
                                } else {
                                    offset = .zero
                                    color = .clear
                                }
                            }
                        }
                    }
            )
            .onTapGesture {
                if reduceMotion {
                    isFlipped.toggle()
                } else {
                    withAnimation(.spring()) {
                        isFlipped.toggle()
                    }
                }
            }
        }
        .padding()
    }
    
    // Parse Seikei content to extract blanks and create blankMap
    private func parseSeikeiContent(_ vocab: Vocabulary) -> (String, [Int: String]) {
        // Use fullText if available, otherwise term
        let sourceText = vocab.fullText ?? vocab.term
        
        // Parse 【answer】 format into [id] placeholders and blankMap
        var content = sourceText
        var blankMap: [Int: String] = [:]
        var blankId = 1
        
        // Find all 【...】 patterns and replace with [id] placeholders
        let pattern = "【([^】]+)】"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(sourceText.startIndex..., in: sourceText)
            let matches = regex.matches(in: sourceText, options: [], range: range)
            
            // Process in reverse to maintain correct string indices
            for match in matches.reversed() {
                if let answerRange = Range(match.range(at: 1), in: sourceText),
                   let fullRange = Range(match.range, in: sourceText) {
                    let answer = String(sourceText[answerRange])
                    blankMap[blankId] = answer
                    content = content.replacingCharacters(in: fullRange, with: "[\(blankId)]")
                    blankId += 1
                }
            }
        }
        
        // If no blanks found and we have allAnswers, use meaning as simple content
        if blankMap.isEmpty, let answers = vocab.allAnswers, !answers.isEmpty {
            // Create simple blank for the main answer
            content = vocab.term
            for (index, answer) in answers.enumerated() {
                blankMap[index + 1] = answer
            }
        }
        
        return (content, blankMap)
    }
}

struct CardContent: View {
    let text: String
    let subtext: String
    let isFront: Bool
    var isRedSheet: Bool = false
    
    var body: some View {
        let theme = ThemeManager.shared
        let danger = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
        let secondary = theme.secondaryText
        VStack(spacing: 20) {
            Text(isFront ? "問題" : "答え")
                .font(.footnote)
                .foregroundColor(secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            if text.contains("<html>") || text.hasPrefix("<ruby>") {
                // Kanbun specialized rendering
                Group {
                    KanbunWebView(kanbunText: text)
                }
                .frame(height: 200)
            } else {
                if isRedSheet {
                    Rectangle()
                        .fill(danger)
                        .overlay(
                            Text("タップで表示")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .frame(height: 100)
                        .cornerRadius(8)
                } else {
                    Text(text)
                        .font(isFront ? .title.weight(.bold) : .title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(isFront ? 2 : 4)
                        .minimumScaleFactor(0.6)
                        .lineLimit(nil)
                        .foregroundColor(ThemeManager.shared.primaryText)
                    
                    if !subtext.isEmpty {
                        Text(subtext)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(ThemeManager.shared.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            Text(isFront ? "タップで答えを表示" : "")
                .font(.footnote)
                .foregroundColor(secondary)
        }
        .padding(24)
    }
}
