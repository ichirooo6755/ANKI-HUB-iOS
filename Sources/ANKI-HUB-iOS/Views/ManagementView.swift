import SwiftUI
import UniformTypeIdentifiers

struct ManagementView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @State private var syncStatus = ""
    @State private var showClearConfirmation = false

    @State private var showBackupExporter = false
    @State private var backupDocument = JSONTextDocument()
    @State private var backupErrorMessage = ""
    
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
                                SettingsIcon(
                                    icon: "icloud.fill",
                                    color: themeManager.color(.primary, scheme: colorScheme),
                                    foregroundColor: themeManager.onColor(for: themeManager.color(.primary, scheme: colorScheme))
                                )
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
                                SettingsIcon(
                                    icon: "square.and.arrow.down.fill",
                                    color: themeManager.color(.mastered, scheme: colorScheme),
                                    foregroundColor: themeManager.onColor(for: themeManager.color(.mastered, scheme: colorScheme))
                                )
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
                            SettingsIcon(
                                icon: "trash.fill",
                                color: themeManager.color(.weak, scheme: colorScheme),
                                foregroundColor: themeManager.onColor(for: themeManager.color(.weak, scheme: colorScheme))
                            )
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
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "anki_hub_backup"
            ) { result in
                if case .failure = result {
                    backupErrorMessage = "バックアップの保存に失敗しました"
                }
            }
            .alert(
                "バックアップ",
                isPresented: Binding(
                    get: { !backupErrorMessage.isEmpty },
                    set: { if !$0 { backupErrorMessage = "" } }
                )
            ) {
                Button("OK") { backupErrorMessage = "" }
            } message: {
                Text(backupErrorMessage)
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
        let formatter = ISO8601DateFormatter()
        let allDefaults = UserDefaults.standard.dictionaryRepresentation()

        let filtered = allDefaults.filter { key, _ in
            key.hasPrefix("anki_hub_") || key == "selectedThemeId"
        }

        guard !filtered.isEmpty else {
            backupErrorMessage = "バックアップ対象のデータがありません"
            return
        }

        var payload: [String: Any] = [:]
        for (key, value) in filtered {
            if let data = value as? Data {
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    payload[key] = json
                } else {
                    payload[key] = data.base64EncodedString()
                }
            } else if let date = value as? Date {
                payload[key] = formatter.string(from: date)
            } else {
                payload[key] = value
            }
        }

        guard JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys])
        else {
            backupErrorMessage = "バックアップの作成に失敗しました"
            return
        }

        backupDocument = JSONTextDocument(text: String(data: data, encoding: .utf8) ?? "")
        showBackupExporter = true
    }
    
    private func clearAllData() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}

private struct JSONTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            self.text = ""
            return
        }
        self.text = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// Previews removed for SPM
