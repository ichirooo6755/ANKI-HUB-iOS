import SwiftUI

#if os(iOS)
import PhotosUI
#endif

struct WallpaperGalleryView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedWallpaper: WallpaperOption = .solid

    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImportingPhoto: Bool = false
    @State private var photoImportError: String = ""
    #endif
    
    enum WallpaperOption: String, CaseIterable, Identifiable {
        case presets = "プリセット"
        case solid = "単色"
        case gradient = "グラデーション"
        case photo = "写真"
        case images = "画像"
        case pattern = "パターン"
        case nature = "自然"
        case abstract = "抽象"
        
        var id: String { rawValue }
    }

    private var imagesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(bundledWallpapers, id: \.self) { filename in
                Button {
                    theme.applyWallpaper(kind: "bundle", value: filename)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .frame(height: 120)
                            .liquidGlass(cornerRadius: 16)

                        #if os(iOS)
                        if let url = Bundle.main.url(forResource: (filename as NSString).deletingPathExtension,
                                                     withExtension: (filename as NSString).pathExtension,
                                                     subdirectory: "Wallpapers"),
                           let data = try? Data(contentsOf: url),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        #endif

                        selectionOverlay(
                            isSelected: isSelected(kind: "bundle", value: filename),
                            cornerRadius: 16
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    let gradients: [(name: String, colors: [Color])] = [
        ("オーシャン", [.blue, .cyan]),
        ("サンセット", [.orange, .pink]),
        ("フォレスト", [.green, .mint]),
        ("ミッドナイト", [Color(red: 0.1, green: 0, blue: 0.3), .black]),
        ("ローズ", [.pink, .purple]),
        ("ラベンダー", [.purple, .indigo]),
        ("ゴールド", [.yellow, .orange]),
        ("アイス", [.cyan, .white]),
    ]
    
    let solidColors: [Color] = [
        .white, .black, .gray,
        .red, .orange, .yellow,
        .green, .mint, .cyan,
        .blue, .indigo, .purple, .pink
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Category Picker
                Picker("カテゴリ", selection: $selectedWallpaper) {
                    ForEach(WallpaperOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                switch selectedWallpaper {
                case .presets:
                    presetsGrid
                case .solid:
                    solidColorGrid
                case .gradient:
                    gradientGrid
                case .photo:
                    photoGrid
                case .images:
                    imagesGrid
                case .pattern:
                    patternGrid
                case .nature:
                    natureGrid
                case .abstract:
                    abstractGrid
                }
            }
            .padding(.top)
        }
        .navigationTitle("壁紙ギャラリー")
        .onAppear {
            // Reflect current selection on open
            switch theme.wallpaperKind {
            case "gradient":
                selectedWallpaper = .gradient
            case "photo":
                selectedWallpaper = .photo
            case "bundle":
                selectedWallpaper = .images
            case "solid":
                selectedWallpaper = .solid
            default:
                selectedWallpaper = .presets
            }
        }
    }

    private struct VisualPreset: Identifiable {
        let id: String
        let name: String
        let wallpaperKind: String
        let wallpaperValue: String
        let themeId: String
        let previewColors: [Color]
    }

    private var presets: [VisualPreset] {
        [
            VisualPreset(
                id: "neo_black",
                name: "ネオブラック",
                wallpaperKind: "gradient",
                wallpaperValue: "#0B0B0D,#00FF7A",
                themeId: "cyberpunk",
                previewColors: [Color(hexOrName: "#0B0B0D") ?? .black, Color(hexOrName: "#00FF7A") ?? .green]
            ),
            VisualPreset(
                id: "signal_red",
                name: "シグナルレッド",
                wallpaperKind: "gradient",
                wallpaperValue: "#0B0B0D,#FF3B30",
                themeId: "dracula",
                previewColors: [Color(hexOrName: "#0B0B0D") ?? .black, Color(hexOrName: "#FF3B30") ?? .red]
            ),
            VisualPreset(
                id: "soft_paper",
                name: "ソフトペーパー",
                wallpaperKind: "solid",
                wallpaperValue: "#F2F2EE",
                themeId: "nordic",
                previewColors: [Color(hexOrName: "#F2F2EE") ?? .white, Color(hexOrName: "#D9D9D5") ?? .gray]
            ),
        ]
    }

    private var presetsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(presets) { preset in
                Button {
                    if preset.wallpaperKind == "gradient" {
                        let parts = preset.wallpaperValue
                            .split(separator: ",")
                            .map { String($0) }
                        if parts.count >= 2,
                            let c1 = Color(hexOrName: parts[0]),
                            let c2 = Color(hexOrName: parts[1]),
                            let h1 = c1.toHexString(),
                            let h2 = c2.toHexString()
                        {
                            theme.applyWallpaper(kind: "gradient", value: "\(h1),\(h2)")
                        }
                    } else if preset.wallpaperKind == "solid" {
                        if let c = Color(hexOrName: preset.wallpaperValue),
                            let h = c.toHexString()
                        {
                            theme.applyWallpaper(kind: "solid", value: h)
                        }
                    }
                    theme.applyTheme(id: preset.themeId)
                } label: {
                    let selected = (
                        theme.selectedThemeId == preset.themeId
                            && theme.wallpaperKind == preset.wallpaperKind
                            && theme.wallpaperValue == preset.wallpaperValue
                    )
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: preset.previewColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 100)
                            .overlay(selectionOverlay(isSelected: selected, cornerRadius: 16))
                        Text(preset.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private let bundledWallpapers: [String] = [
        "IMG_5274.jpg",
        "IMG_5275.jpg",
        "IMG_5276.jpg",
        "IMG_5277.jpg",
        "IMG_5278.jpg"
    ]

    private func isSelected(kind: String, value: String) -> Bool {
        theme.wallpaperKind == kind && theme.wallpaperValue == value
    }

    private func selectionOverlay(isSelected: Bool, cornerRadius: CGFloat) -> some View {
        let borderColor = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isSelected ? borderColor : .secondary.opacity(0.6), lineWidth: isSelected ? 3 : 1)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(borderColor)
                    .background(
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 24, height: 24)
                            .liquidGlassCircle()
                    )
                    .offset(x: 6, y: -6)
            }
        }
    }
    
    private var solidColorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            ForEach(solidColors, id: \.self) { color in
                Button {
                    if let hex = color.toHexString() {
                        theme.applyWallpaper(kind: "solid", value: hex)
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .frame(height: 60)
                        .overlay(selectionOverlay(isSelected: isSelected(kind: "solid", value: color.toHexString() ?? ""), cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var gradientGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(gradients, id: \.name) { gradient in
                Button {
                    let c1 = gradient.colors.first
                    let c2 = gradient.colors.dropFirst().first
                    if let c1, let c2,
                       let h1 = c1.toHexString(),
                       let h2 = c2.toHexString() {
                        theme.applyWallpaper(kind: "gradient", value: "\(h1),\(h2)")
                    }
                } label: {
                    let c1 = gradient.colors.first
                    let c2 = gradient.colors.dropFirst().first
                    let value: String = {
                        if let c1, let c2, let h1 = c1.toHexString(), let h2 = c2.toHexString() {
                            return "\(h1),\(h2)"
                        }
                        return ""
                    }()
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: gradient.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 100)
                            .overlay(selectionOverlay(isSelected: isSelected(kind: "gradient", value: value), cornerRadius: 16))
                        Text(gradient.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var photoGrid: some View {
        #if os(iOS)
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .frame(height: 140)
                        .liquidGlass(cornerRadius: 16)

                    if let img = loadPhotoFromDocuments(filename: theme.wallpaperValue), theme.wallpaperKind == "photo" {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(selectionOverlay(isSelected: true, cornerRadius: 16))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                                .foregroundStyle(theme.primaryText)
                            Text("写真を選択")
                                .font(.headline)
                                .foregroundStyle(theme.primaryText)
                            Text("背景に設定")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }

                    if isImportingPhoto {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .padding(.horizontal)
            .disabled(isImportingPhoto)
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                importPhoto(item)
            }

            if !photoImportError.isEmpty {
                Text(photoImportError)
                    .font(.caption)
                    .foregroundStyle(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
                    .padding(.horizontal)
            }
        }
        #else
        VStack {
            Text("写真壁紙はiOSで利用できます")
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        #endif
    }

    #if os(iOS)
    private func importPhoto(_ item: PhotosPickerItem) {
        photoImportError = ""
        isImportingPhoto = true
        Task {
            defer { isImportingPhoto = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { photoImportError = "写真の読み込みに失敗しました" }
                    return
                }
                guard let uiImage = UIImage(data: data) else {
                    await MainActor.run { photoImportError = "画像データを解析できませんでした" }
                    return
                }
                guard let jpeg = uiImage.jpegData(compressionQuality: 0.92) else {
                    await MainActor.run { photoImportError = "画像の保存に失敗しました" }
                    return
                }

                let filename = "wallpaper_\(UUID().uuidString).jpg"
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                guard let url = docs?.appendingPathComponent(filename) else {
                    await MainActor.run { photoImportError = "保存先を作成できませんでした" }
                    return
                }
                try jpeg.write(to: url, options: .atomic)

                await MainActor.run {
                    theme.applyWallpaper(kind: "photo", value: filename)
                }
            } catch {
                await MainActor.run { photoImportError = "写真の読み込みに失敗しました" }
            }
        }
    }

    private func loadPhotoFromDocuments(filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    #endif
    
    private var patternGrid: some View {
        VStack {
            Text("パターン壁紙は近日公開")
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
    }
    
    private var natureGrid: some View {
        VStack {
            Text("自然壁紙は近日公開")
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
    }
    
    private var abstractGrid: some View {
        VStack {
            Text("抽象壁紙は近日公開")
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
    }
}

// Previews removed for SPM
