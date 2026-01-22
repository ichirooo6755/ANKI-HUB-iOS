import SwiftUI

struct LockScreenMirrorGuideView: View {
    @ObservedObject private var theme = ThemeManager.shared

    private let docURL = URL(string: "https://developer.apple.com/documentation/LockedCameraCapture")!

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                guideCard
                behaviorCard
                requirementsCard
                developerCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("ロック画面ミラー")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .applyAppTheme()
    }

    private var heroCard: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)

        return HStack(spacing: 16) {
            SettingsIcon(
                icon: "camera.viewfinder",
                color: accent,
                foregroundColor: theme.onColor(for: accent)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("ロック画面からミラーを起動")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
            }

            Spacer()
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20)
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("追加手順")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            VStack(spacing: 10) {
                GuideStepRow(
                    index: "1",
                    title: "ロック画面を長押し",
                    detail: ""
                )
                GuideStepRow(
                    index: "2",
                    title: "ロック画面タブを選択",
                    detail: ""
                )
                GuideStepRow(
                    index: "3",
                    title: "コントロールの「+」をタップ",
                    detail: ""
                )
                GuideStepRow(
                    index: "4",
                    title: "追加後はロック画面から起動",
                    detail: ""
                )
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20)
    }

    private var behaviorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ロック中の挙動")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 6) {
                InfoRow(text: "ロック中はミラー表示のみ（撮影・保存なし）")
                InfoRow(text: "追加操作は認証してアプリで完了")
                InfoRow(text: "アプリのミラー画面と同じUIを使用")
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20)
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("対応要件")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 6) {
                InfoRow(text: "iOS 18 以降が必要")
                InfoRow(text: "カメラ権限を許可して利用")
                InfoRow(text: "Face ID / Touch IDで解除するとアプリへ")
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20)
    }

    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("開発者向け参考")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            Text("LockedCameraCaptureのガイドに準拠しています")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)

            Link("LockedCameraCapture (Apple Developer)", destination: docURL)
                .font(.caption)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20)
    }
}

private struct GuideStepRow: View {
    let index: String
    let title: String
    let detail: String

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(index)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 24, height: 24)
                .background(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            Spacer()
        }
    }
}

private struct InfoRow: View {
    let text: String

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Spacer()
        }
    }
}
