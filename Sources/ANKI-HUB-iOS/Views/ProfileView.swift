import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ProfileView: View {
    @EnvironmentObject var learningStats: LearningStats
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @State private var showLogoutConfirm: Bool = false
    @State private var syncStatus: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.color(.primary, scheme: colorScheme))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.displayName ?? "ゲスト")
                                .font(.title2.bold())
                            Text(authManager.currentUser?.email ?? "ログインしていません")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.secondaryText)
                            if authManager.currentUser != nil {
                                Text(authManager.isInvited ? "プレミアム" : "無料プラン")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background((authManager.isInvited ? themeManager.color(.mastered, scheme: colorScheme) : themeManager.color(.border, scheme: colorScheme)).opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Stats
                Section("学習統計") {
                    HStack {
                        Label("連続学習日数", systemImage: "flame.fill")
                        Spacer()
                        Text("\(learningStats.streak) 日")
                            .foregroundColor(themeManager.color(.accent, scheme: colorScheme))
                    }
                    HStack {
                        Label("今日の学習", systemImage: "clock.fill")
                        Spacer()
                        Text("\(learningStats.todayMinutes) 分")
                            .foregroundColor(themeManager.color(.primary, scheme: colorScheme))
                    }
                    HStack {
                        Label("覚えた単語", systemImage: "checkmark.circle.fill")
                        Spacer()
                        Text("\(learningStats.masteredCount) 語")
                            .foregroundColor(themeManager.color(.mastered, scheme: colorScheme))
                    }
                }
                
                // Theme Settings
                Section("テーマ") {
                    NavigationLink(destination: ThemeSettingsView()) {
                        Label("テーマ設定", systemImage: "paintpalette")
                    }
                }

                Section("学習") {
                    NavigationLink(destination: WeakWordsView()) {
                        Label("苦手一括復習", systemImage: "exclamationmark.triangle.fill")
                    }
                }

                if authManager.currentUser != nil && authManager.isInvited {
                    Section("同期") {
                        Button {
                            syncStatus = "同期中..."
                            Task {
                                await SyncManager.shared.syncAllDebounced()
                                syncStatus = "完了"
                                try? await Task.sleep(for: .seconds(2))
                                syncStatus = ""
                            }
                        } label: {
                            HStack {
                                Label("クラウド同期", systemImage: "icloud")
                                Spacer()
                                if !syncStatus.isEmpty {
                                    Text(syncStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Account Actions
                Section {
                    if authManager.currentUser != nil {
                        Button(role: .destructive) {
                            showLogoutConfirm = true
                        } label: {
                            Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        NavigationLink(destination: AuthView()) {
                            Label("ログイン", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("プロフィール")
            .alert("ログアウト", isPresented: $showLogoutConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("本当にログアウトしますか？")
            }
        }
        .scrollContentBackground(.hidden)
        .listRowBackground(themeManager.color(.surface, scheme: colorScheme))
        .background(ThemeManager.shared.background)
        .onAppear {
            #if os(iOS)
            UITableView.appearance().backgroundColor = .clear
            #endif
        }
    }
}

// Previews removed for SPM
