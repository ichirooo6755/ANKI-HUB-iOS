import SwiftUI

#if os(iOS)
    import PhotosUI
    import UIKit
#endif

struct BookshelfView: View {
    @StateObject private var manager = StudyMaterialManager.shared
    @ObservedObject private var theme = ThemeManager.shared

    @State private var searchText: String = ""
    @State private var filterSubject: Subject? = nil
    @State private var showAddSheet = false

    private var filteredMaterials: [StudyMaterial] {
        var result = manager.materials
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let filterSubject {
            result = result.filter { $0.subject == filterSubject }
        }
        return result
    }

    private var recentRecords: [StudyMaterialRecord] {
        Array(manager.records.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    VStack(spacing: 20) {
                        SectionHeader(
                            title: "教材ライブラリ",
                            subtitle: "学習素材と記録をまとめて管理",
                            trailing: "\(manager.materials.count)件"
                        )

                        summaryMetrics

                        searchBar

                        filterChips

                        if filteredMaterials.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredMaterials) { material in
                                    NavigationLink {
                                        MaterialDetailView(materialId: material.id)
                                    } label: {
                                        MaterialCardView(material: material)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !recentRecords.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(
                                    title: "最近の学習記録",
                                    subtitle: "最新\(recentRecords.count)件",
                                    trailing: nil
                                )

                                VStack(spacing: 10) {
                                    ForEach(recentRecords) { record in
                                        MaterialRecordRow(record: record)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                                    .opacity(theme.effectiveIsDark ? 0.95 : 0.98)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("教材")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showAddSheet) {
                AddMaterialSheet(manager: manager, material: nil)
            }
        }
        .applyAppTheme()
        .onAppear {
            manager.load()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.secondaryText)
            TextField("教材を検索", text: $searchText)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.currentPalette.color(.border, isDark: theme.effectiveIsDark).opacity(0.3), lineWidth: 1)
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    filterSubject = nil
                } label: {
                    chipLabel(title: "すべて", isSelected: filterSubject == nil)
                }
                .buttonStyle(.plain)

                ForEach(Subject.allCases) { subject in
                    Button {
                        filterSubject = subject
                    } label: {
                        chipLabel(title: subject.displayName, isSelected: filterSubject == subject)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chipLabel(title: String, isSelected: Bool) -> some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        return Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? accent : surface.opacity(0.85))
            .foregroundStyle(isSelected ? theme.onColor(for: accent) : theme.primaryText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(border.opacity(isSelected ? 0 : 0.6), lineWidth: 1)
            )
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark).opacity(0.2),
                                theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark),
                                theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("学習を始めましょう")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                
                Text("教材を登録して学習記録をつければ、\nあなたの成長を可視化できます")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                    Text("教材を追加")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(theme.onColor(for: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark),
                            theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var summaryMetrics: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        return HStack(spacing: 12) {
            HealthMetricCard(
                title: "総学習時間",
                value: formatMinutes(totalMinutes),
                unit: "",
                icon: "hourglass",
                color: accent
            )
            HealthMetricCard(
                title: "学習記録",
                value: "\(manager.records.count)",
                unit: "件",
                icon: "clock.arrow.circlepath",
                color: primary
            )
        }
    }

    private var totalMinutes: Int {
        manager.materials.reduce(0) { $0 + $1.totalMinutes }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)分" }
        if remainder == 0 { return "\(hours)時間" }
        return "\(hours)時間\(remainder)分"
    }
}

fileprivate func formatMinutes(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)分" }
    if remainder == 0 { return "\(hours)時間" }
    return "\(hours)時間\(remainder)分"
}

private struct MaterialCardView: View {
    let material: StudyMaterial
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let accent = material.subject?.color
            ?? theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.25))
                    .frame(width: 52, height: 52)
                Image(systemName: material.type.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(material.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                HStack(spacing: 8) {
                    if let subject = material.subject {
                        PillBadge(title: subject.displayName, color: subject.color)
                    }
                    PillBadge(title: material.type.rawValue, color: accent)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatMinutes(material.totalMinutes))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                }
                if let last = material.lastStudiedAt {
                    Text(dateString(last))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: accent.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct MaterialRecordRow: View {
    let record: StudyMaterialRecord
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.materialTitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText)
                Text(record.note.isEmpty ? "学習記録" : record.note)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.minutes)分")
                    .font(.caption)
                    .foregroundStyle(theme.primaryText)
                Text(dateString(record.endedAt))
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                .opacity(theme.effectiveIsDark ? 0.92 : 0.96)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.currentPalette.color(.border, isDark: theme.effectiveIsDark).opacity(0.2), lineWidth: 1)
        )
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MaterialDetailView: View {
    let materialId: UUID
    @StateObject private var manager = StudyMaterialManager.shared
    @ObservedObject private var theme = ThemeManager.shared

    @State private var showEditSheet = false
    @State private var showRecordSheet = false
    @State private var showDeleteConfirm = false

    private var material: StudyMaterial? {
        manager.materials.first(where: { $0.id == materialId })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                ScrollView {
                    if let material {
                        VStack(spacing: 20) {
                            MaterialHeaderView(material: material)

                            statsCard(material: material)

                            if !material.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    SectionHeader(title: "メモ", subtitle: nil, trailing: nil)
                                    Text(material.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.primaryText)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                                        .opacity(theme.effectiveIsDark ? 0.95 : 0.98)
                                )
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline) {
                                    SectionHeader(title: "学習記録", subtitle: nil, trailing: nil)
                                    Spacer()
                                    Button(action: {
                                        showRecordSheet = true
                                    }) {
                                        PillBadge(
                                            title: "追加",
                                            color: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                let records = manager.records(for: material.id)
                                if records.isEmpty {
                                    Text("学習記録がまだありません")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(records) { record in
                                            MaterialRecordRow(record: record)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    } else {
                        ContentUnavailableView("教材が見つかりません", systemImage: "books.vertical")
                            .padding(.top, 40)
                    }
                }
            }
            .navigationTitle("教材")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("編集") { showEditSheet = true }
                        Button("記録を追加") { showRecordSheet = true }
                        Divider()
                        Button("削除", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("編集") { showEditSheet = true }
                        Button("記録を追加") { showRecordSheet = true }
                        Divider()
                        Button("削除", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
#endif
            }
            .confirmationDialog("教材を削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    if let material {
                        manager.deleteMaterial(material)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let material {
                    AddMaterialSheet(manager: manager, material: material)
                }
            }
            .sheet(isPresented: $showRecordSheet) {
                ManualRecordSheet(materialId: materialId)
            }
        }
        .applyAppTheme()
    }

    private func statsCard(material: StudyMaterial) -> some View {
        let totalMinutes = formatMinutes(material.totalMinutes)
        let lastStudied = material.lastStudiedAt.map(dateString) ?? "未記録"
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        return HStack(spacing: 12) {
            HealthMetricCard(
                title: "累計",
                value: totalMinutes,
                unit: "",
                icon: "hourglass",
                color: accent
            )
            HealthMetricCard(
                title: "最終学習",
                value: lastStudied,
                unit: "",
                icon: "clock.fill",
                color: primary
            )
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)分" }
        if remainder == 0 { return "\(hours)時間" }
        return "\(hours)時間\(remainder)分"
    }
}

private struct MaterialHeaderView: View {
    let material: StudyMaterial
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                    .frame(width: 90, height: 90)

#if os(iOS)
                if let image = loadMaterialImage(material.imageFilename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Image(systemName: material.type.icon)
                        .font(.system(size: 34))
                        .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                }
#else
                Image(systemName: material.type.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
#endif
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(material.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                HStack(spacing: 6) {
                    if let subject = material.subject {
                        Label(subject.displayName, systemImage: subject.icon)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Text(material.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer()
        }
    }

#if os(iOS)
    private func loadMaterialImage(_ filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }
#endif
}

struct AddMaterialSheet: View {
    @ObservedObject var manager: StudyMaterialManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ThemeManager.shared

    let material: StudyMaterial?

    @State private var title: String = ""
    @State private var subject: Subject? = nil
    @State private var type: StudyMaterial.MaterialType = .book
    @State private var notes: String = ""
    @State private var imageFilename: String? = nil
    @State private var photoError = ""

    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("教材") {
                    TextField("教材名", text: $title)

                    Picker("科目", selection: $subject) {
                        Text("未設定").tag(Subject?.none)
                        ForEach(Subject.allCases) { subject in
                            Text(subject.displayName).tag(Optional(subject))
                        }
                    }

                    Picker("種別", selection: $type) {
                        ForEach(StudyMaterial.MaterialType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("メモ") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                #if os(iOS)
                Section("写真") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                            Text(previewImage == nil ? "写真を追加" : "写真を変更")
                        }
                    }

                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if let filename = imageFilename,
                        let image = loadMaterialImage(filename)
                    {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if !photoError.isEmpty {
                        Text(photoError)
                            .font(.caption)
                            .foregroundStyle(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
                    }
                }
                #endif
            }
            .navigationTitle(material == nil ? "教材を追加" : "教材を編集")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveMaterial()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            #if os(iOS)
                .onChange(of: selectedPhotoItem) { _, item in
                    guard let item else { return }
                    importPhoto(item)
                }
            #endif
        }
        .applyAppTheme()
        .onAppear {
            if let material {
                title = material.title
                subject = material.subject
                type = material.type
                notes = material.notes
                imageFilename = material.imageFilename
            }
        }
    }

    private func saveMaterial() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        var newFilename = imageFilename
        #if os(iOS)
        if let previewImage {
            newFilename = saveMaterialImage(previewImage)
        }
        #endif

        if var existing = material {
            existing.title = trimmedTitle
            existing.subject = subject
            existing.type = type
            existing.notes = trimmedNotes
            if let newFilename, newFilename != existing.imageFilename {
                deleteMaterialImage(existing.imageFilename)
                existing.imageFilename = newFilename
            }
            manager.updateMaterial(existing)
        } else {
            let newMaterial = StudyMaterial(
                title: trimmedTitle,
                subject: subject,
                type: type,
                notes: trimmedNotes,
                imageFilename: newFilename
            )
            manager.addMaterial(newMaterial)
        }
    }

    #if os(iOS)
    private func importPhoto(_ item: PhotosPickerItem) {
        photoError = ""
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                else {
                    await MainActor.run { photoError = "写真の読み込みに失敗しました" }
                    return
                }
                await MainActor.run {
                    previewImage = image
                }
            } catch {
                await MainActor.run { photoError = "写真の読み込みに失敗しました" }
            }
        }
    }

    private func saveMaterialImage(_ image: UIImage) -> String? {
        guard let jpeg = image.jpegData(compressionQuality: 0.92) else { return nil }
        let filename = "material_\(UUID().uuidString).jpg"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename) else { return nil }
        do {
            try jpeg.write(to: url, options: .atomic)
            return filename
        } catch {
            photoError = "写真の保存に失敗しました"
            return nil
        }
    }

    private func loadMaterialImage(_ filename: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }
    #endif

    private func deleteMaterialImage(_ filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

struct ManualRecordSheet: View {
    let materialId: UUID
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = ThemeManager.shared
    @StateObject private var manager = StudyMaterialManager.shared

    @State private var minutes: Int = 30
    @State private var note: String = ""
    @State private var endedAt: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("学習時間") {
                    Stepper("\(minutes)分", value: $minutes, in: 5...480, step: 5)
                }

                Section("日時") {
                    DatePicker("記録日時", selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("メモ") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("学習記録を追加")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let duration = TimeInterval(minutes * 60)
                        let started = endedAt.addingTimeInterval(-duration)
                        manager.addRecord(
                            materialId: materialId,
                            minutes: minutes,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            startedAt: started,
                            endedAt: endedAt,
                            source: .manual
                        )
                        dismiss()
                    }
                }
            }
        }
        .applyAppTheme()
        .tint(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
    }
}