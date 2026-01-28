import SwiftUI

// MARK: - Pin Recording Sheet

/// Sheet for recording pin details
struct PinRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var sessionManager = StudySessionManager.shared
    
    @State private var selectedSubject: Subject = .english
    @State private var activity: String = ""
    @State private var notes: String = ""
    
    private let activities = [
        "単語学習",
        "文法学習",
        "問題演習",
        "復習",
        "暗記",
        "読解",
        "リスニング",
        "その他"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                
                Form {
                    Section("科目") {
                        Picker("科目を選択", selection: $selectedSubject) {
                            ForEach(Subject.allCases) { subject in
                                HStack {
                                    Image(systemName: subject.icon)
                                    Text(subject.displayName)
                                }
                                .tag(subject)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Section("活動内容") {
                        Picker("活動", selection: $activity) {
                            ForEach(activities, id: \.self) { act in
                                Text(act).tag(act)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Section("メモ（任意）") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    }
                    
                    Section {
                        if sessionManager.activeSession != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("このセグメントの時間")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                Text(sessionManager.formattedCurrentSegmentTime())
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("ピンを打つ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        savePin()
                    }
                    .disabled(activity.isEmpty)
                }
            }
            .onAppear {
                if activity.isEmpty {
                    activity = activities[0]
                }
            }
        }
    }
    
    private func savePin() {
        sessionManager.addPin(
            subject: selectedSubject.rawValue,
            activity: activity,
            notes: notes
        )
        dismiss()
    }
}

// MARK: - Study Session Bento Card

/// Horizontal bento-style card for starting/managing study sessions
struct StudySessionBentoCard: View {
    @ObservedObject private var sessionManager = StudySessionManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var showPinSheet = false
    @State private var showStopConfirmation = false
    
    var body: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let shadow = Color.black.opacity(theme.effectiveIsDark ? 0.24 : 0.06)
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        
        return ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    accent.opacity(theme.effectiveIsDark ? 0.25 : 0.15),
                    accent.opacity(theme.effectiveIsDark ? 0.15 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if sessionManager.isSessionActive {
                activeSessionContent
            } else {
                inactiveSessionContent
            }
        }
        .frame(height: 120)
        .background(cardShape.fill(surface.opacity(theme.effectiveIsDark ? 0.9 : 0.98)))
        .overlay(
            cardShape.stroke(accent.opacity(0.3), lineWidth: 1.5)
        )
        .clipShape(cardShape)
        .shadow(color: shadow, radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showPinSheet) {
            PinRecordingSheet()
        }
        .alert("学習セッションを終了", isPresented: $showStopConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("終了", role: .destructive) {
                sessionManager.stopSession()
            }
        } message: {
            Text("学習セッションを終了しますか？記録は保存されます。")
        }
    }
    
    private var inactiveSessionContent: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark).opacity(0.2))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("勉強スタート")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                
                Text("学習セッションを開始して記録を残そう")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            
            Spacer()
            
            // Start button
            Button {
                sessionManager.startSession()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var activeSessionContent: some View {
        VStack(spacing: 12) {
            // Timer display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("学習中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                    
                    Text(sessionManager.formattedElapsedTime())
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                }
                
                Spacer()
                
                // Pulsing indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.5)
                    )
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Pin button
                Button {
                    showPinSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pin.fill")
                            .font(.caption.weight(.semibold))
                        Text("ピン")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    )
                }
                
                Spacer()
                
                // Current segment time
                VStack(alignment: .trailing, spacing: 2) {
                    Text("現在のセグメント")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                    Text(sessionManager.formattedCurrentSegmentTime())
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)
                }
                
                // Stop button
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
