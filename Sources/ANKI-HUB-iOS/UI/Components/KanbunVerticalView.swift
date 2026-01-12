import SwiftUI

struct KanbunVerticalView: View {
    let text: String
    let fontSize: CGFloat = 24
    
    // Simple vertical text implementation
    // Splits text into lines and arranges them horizontally (RTL)
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(splitLines(text), id: \.self) { line in
                VStack(spacing: 2) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: fontSize, design: .serif))
                            .padding(.vertical, -2)
                            .foregroundColor(ThemeManager.shared.primaryText)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft) // Make HStack lay out from right to left
    }
    
    func splitLines(_ input: String) -> [String] {
        // Simple splitter by newline, but for Kanbun we might need auto-wrap later.
        // For now, assume manual newlines or short text.
        return input.components(separatedBy: "\n")
    }
}

// Preview
struct KanbunVerticalView_Previews: PreviewProvider {
    static var previews: some View {
        KanbunVerticalView(text: "国破山河在\n城春草木深")
            .padding()
            .background(ThemeManager.shared.background)
    }
}
