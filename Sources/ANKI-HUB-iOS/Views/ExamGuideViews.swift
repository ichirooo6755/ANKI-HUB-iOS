import SwiftUI

struct ExamGuideHomeView: View {
    @ObservedObject private var theme = ThemeManager.shared
    private let subjects = ExamGuideData.subjects()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionHeader(
                    title: "試験解説",
                    subtitle: "YouTube要約・Manaba問題・期末PDFを試験向けに整理",
                    trailing: "\(subjects.count)科目"
                )

                if subjects.isEmpty {
                    ContentUnavailableView(
                        "解説データがありません",
                        systemImage: "text.book.closed",
                        description: Text("exam_guides.json を確認してください")
                    )
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(subjects) { subject in
                            NavigationLink {
                                ExamGuideSectionListView(subject: subject)
                            } label: {
                                ExamGuideSubjectCard(subject: subject)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(theme.background)
        .navigationTitle("試験解説")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .applyAppTheme()
    }
}

private struct ExamGuideSubjectCard: View {
    let subject: ExamGuideSubject
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let accent = subjectAccent
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.22))
                    .frame(width: 52, height: 52)
                Image(systemName: "text.book.closed.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(subject.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(subject.subtitle)
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(subject.sections.count)章")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1.5)
        )
    }

    private var subjectAccent: Color {
        switch subject.id {
        case "accounting":
            return theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        case "manefi":
            return theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        default:
            return theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        }
    }
}

struct ExamGuideSectionListView: View {
    let subject: ExamGuideSubject
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(subject.sections) { section in
                    NavigationLink {
                        ExamGuideDetailView(subject: subject, section: section)
                    } label: {
                        ExamGuideSectionRow(section: section)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(theme.background)
        .navigationTitle(subject.title)
        .applyAppTheme()
    }
}

private struct ExamGuideSectionRow: View {
    let section: ExamGuideSection
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.leading)
                if let subtitle = section.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(border.opacity(0.45))
                .frame(height: 1)
        }
    }
}

struct ExamGuideDetailView: View {
    let subject: ExamGuideSubject
    let section: ExamGuideSection
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let links = section.youtubeLinks, !links.isEmpty {
                    youtubeSection(links)
                }

                ForEach(section.blocks) { block in
                    ExamGuideBlockView(block: block)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(theme.background)
        .navigationTitle(section.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .applyAppTheme()
    }

    @ViewBuilder
    private func youtubeSection(_ links: [ExamGuideYouTubeLink]) -> some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        VStack(alignment: .leading, spacing: 12) {
            Label("関連動画", systemImage: "play.rectangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            ForEach(links) { link in
                if let url = URL(string: link.url) {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(accent)
                            Text(link.title)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(theme.primaryText)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(surface)
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
        )
    }
}

private struct ExamGuideBlockView: View {
    let block: ExamGuideBlock
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        switch block.type {
        case "heading":
            Text(block.text ?? "")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .padding(.top, 4)
        case "subheading":
            Text(block.text ?? "")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
        case "paragraph":
            Text(block.text ?? "")
                .font(.body)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        case "bullets":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(block.items ?? [], id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(theme.secondaryText)
                        Text(item)
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case "practice":
            practiceCard
        default:
            EmptyView()
        }
    }

    private var practiceCard: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        return VStack(alignment: .leading, spacing: 10) {
            Label("練習解説", systemImage: "checkmark.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)

            if let question = block.question {
                Text(question)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(theme.primaryText)
            }

            if let answer = block.answer {
                HStack(alignment: .top, spacing: 8) {
                    Text("正解")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.18))
                        .foregroundStyle(accent)
                        .clipShape(Capsule())
                    Text(answer)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
            }

            if let explanation = block.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}
