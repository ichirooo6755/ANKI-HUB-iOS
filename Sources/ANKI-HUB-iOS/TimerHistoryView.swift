import SwiftUI

struct TimerHistoryView: View {
    let history: [PomodoroView.TimerHistoryEntry]
    let onEntrySelected: (PomodoroView.TimerHistoryEntry) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(history) { entry in
                    Button(action: {
                        onEntrySelected(entry)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(entry.minutes)分")
                                    .font(.headline)
                                    .foregroundStyle(theme.primaryText)
                                Text(entry.mode)
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                Text(formatDate(entry.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("タイマー履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .background(theme.background)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
