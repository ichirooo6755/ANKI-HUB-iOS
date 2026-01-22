import SwiftUI

struct SyncStatusIndicator: View {
    @ObservedObject var syncManager = SyncManager.shared
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: syncIcon)
                .rotationEffect(.degrees(rotation))
                .foregroundColor(syncColor)
                .onChange(of: syncManager.isSyncing) { _, isSyncing in
                    if isSyncing {
                        if reduceMotion {
                            rotation = 0
                        } else {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                    } else {
                        if reduceMotion {
                            rotation = 0
                        } else {
                            withAnimation {
                                rotation = 0
                            }
                        }
                    }
                }

            if syncManager.isSyncing {
                Text("同期中...")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            } else if let lastSync = syncManager.lastSyncDate {
                Text(timeAgo(date: lastSync))
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        .padding(6)
        .liquidGlass()
    }

    var syncIcon: String {
        if syncManager.isSyncing { return "arrow.triangle.2.circlepath" }
        return "checkmark.icloud.fill"
    }

    var syncColor: Color {
        if syncManager.isSyncing { return .blue }
        return .green
    }

    func timeAgo(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
