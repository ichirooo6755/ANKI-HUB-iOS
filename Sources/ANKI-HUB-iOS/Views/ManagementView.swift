import SwiftUI

struct ManagementView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @State private var syncStatus = ""
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section("外観") {
                    Picker("外観", selection: $themeManager.colorSchemeOverride) {
                        Text("システム").tag(0)
                        Text("ライト").tag(1)
                        Text("ダーク").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Data Section
                Section("データ") {
                    Button {
                        syncData()
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("クラウド同期")
                                    Text(syncStatus.isEmpty ? "タップして同期" : syncStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "icloud.fill")
                                    .foregroundStyle(
                                        themeManager.onColor(for: themeManager.color(.primary, scheme: colorScheme))
                                    )
                                    .frame(width: 28, height: 28)
                                    .background(themeManager.color(.primary, scheme: colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        exportBackup()
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("バックアップ")
                                    Text("JSONファイルとして保存")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .foregroundStyle(
                                        themeManager.onColor(for: themeManager.color(.mastered, scheme: colorScheme))
                                    )
                                    .frame(width: 28, height: 28)
                                    .background(themeManager.color(.mastered, scheme: colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("データを削除")
                                    .foregroundStyle(themeManager.color(.weak, scheme: colorScheme))
                                Text("すべての学習データを消去")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(
                                    themeManager.onColor(for: themeManager.color(.weak, scheme: colorScheme))
                                )
                                .frame(width: 28, height: 28)
                                .background(themeManager.color(.weak, scheme: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                
                // About Section
                Section("アプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("ビルド")
                        Spacer()
                        Text("SwiftUI Native")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("管理")
            .confirmationDialog(
                "すべてのデータを削除しますか？",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    clearAllData()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }
    
    private func syncData() {
        syncStatus = "同期中..."
        Task {
            await SyncManager.shared.syncAllDebounced()
            syncStatus = "完了"
            try? await Task.sleep(for: .seconds(2))
            syncStatus = ""
        }
    }
    
    private func exportBackup() {
        // Export UserDefaults data as JSON
    }
    
    private func clearAllData() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}

// Previews removed for SPM
