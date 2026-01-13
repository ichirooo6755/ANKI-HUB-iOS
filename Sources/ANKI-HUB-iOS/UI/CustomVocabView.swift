import SwiftUI

struct CustomVocabView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var word: String = ""
    @State private var meaning: String = ""
    @State private var items: [CustomItem] = []
    
    struct CustomItem: Identifiable {
        let id = UUID()
        let word: String
        let meaning: String
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.word).font(.headline)
                        Text(item.meaning).font(.caption).foregroundStyle(theme.secondaryText)
                    }
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }
            }
            
            VStack(spacing: 12) {
                TextField("単語 / 問題", text: $word)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("意味 / 答え", text: $meaning)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addItem) {
                    let bg = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                    Text("追加する")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bg)
                        .foregroundStyle(theme.onColor(for: bg))
                        .cornerRadius(10)
                }
                .disabled(word.isEmpty || meaning.isEmpty)
            }
            .padding()
            .liquidGlass(cornerRadius: 12)
        }
        .navigationTitle("カスタム単語帳")
    }
    
    func addItem() {
        let newItem = CustomItem(word: word, meaning: meaning)
        items.append(newItem)
        word = ""
        meaning = ""
    }
}
