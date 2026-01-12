import SwiftUI

#if os(iOS)
    import VisionKit
    import UIKit
#endif

struct ScanView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var showScanner = false

    #if os(iOS)
        @State private var scannedImages: [UIImage] = []
        @State private var recognizedText: String = ""
        @State private var extractedWords: [ExtractedWord] = []
        @State private var isRecognizing: Bool = false
    #endif

    struct ExtractedWord: Identifiable {
        let id = UUID()
        let term: String
        let meaning: String
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                #if os(iOS)
                    if scannedImages.isEmpty {
                        VStack(spacing: 24) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)

                            Text("Scan Textbooks")
                                .font(.title.bold())

                            Text(
                                "Use the camera to scan pages from your textbooks to create custom flashcards."
                            )
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                            Button {
                                showScanner = true
                            } label: {
                                let bg = theme.currentPalette.color(
                                    .primary, isDark: theme.effectiveIsDark)
                                Label("Start Scanning", systemImage: "camera.fill")
                                    .font(.headline)
                                    .foregroundStyle(theme.onColor(for: bg))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(bg)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16)
                                {
                                    ForEach(scannedImages, id: \.self) { image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(8)
                                            .shadow(radius: 2)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("抽出テキスト")
                                        .font(.headline)

                                    TextEditor(text: $recognizedText)
                                        .frame(minHeight: 160)
                                        .padding(8)
                                        .liquidGlass()
                                }
                                .padding(.horizontal)

                                if isRecognizing {
                                    ProgressView("OCR中...")
                                        .padding(.vertical)
                                }

                                VStack(spacing: 12) {
                                    Button {
                                        Task { await runOCR() }
                                    } label: {
                                        let bg = theme.currentPalette.color(
                                            .mastered, isDark: theme.effectiveIsDark)
                                        Label("OCRを実行", systemImage: "text.viewfinder")
                                            .font(.headline)
                                            .foregroundStyle(theme.onColor(for: bg))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(bg)
                                            .cornerRadius(12)
                                    }
                                    .disabled(isRecognizing)

                                    Button {
                                        extractWordsFromText()
                                    } label: {
                                        let bg = theme.currentPalette.color(
                                            .selection, isDark: theme.effectiveIsDark)
                                        Label("単語を抽出", systemImage: "wand.and.stars")
                                            .font(.headline)
                                            .foregroundStyle(theme.onColor(for: bg))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(bg)
                                            .cornerRadius(12)
                                    }

                                    if !extractedWords.isEmpty {
                                        Button {
                                            addToWordbook()
                                        } label: {
                                            let bg = theme.currentPalette.color(
                                                .primary, isDark: theme.effectiveIsDark)
                                            Label(
                                                "単語帳に追加 (\(extractedWords.count))",
                                                systemImage: "bookmark.fill"
                                            )
                                            .font(.headline)
                                            .foregroundStyle(theme.onColor(for: bg))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(bg)
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal)

                                if !extractedWords.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("抽出結果")
                                            .font(.headline)

                                        ForEach(extractedWords) { w in
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(w.term).font(.headline)
                                                    Text(w.meaning).font(.caption).foregroundStyle(
                                                        .secondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(10)
                                            .liquidGlass()
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                Spacer(minLength: 80)
                            }
                            .padding(.top)
                        }
                        .overlay(alignment: .bottom) {
                            HStack(spacing: 12) {
                                Button {
                                    showScanner = true
                                } label: {
                                    Label("追加でスキャン", systemImage: "plus")
                                        .font(.headline)
                                        .foregroundStyle(theme.primaryText)
                                        .padding()
                                        .liquidGlass()
                                }

                                Button {
                                    resetAll()
                                } label: {
                                    let bg = theme.currentPalette.color(
                                        .weak, isDark: theme.effectiveIsDark)
                                    Label("リセット", systemImage: "trash")
                                        .font(.headline)
                                        .foregroundStyle(theme.onColor(for: bg))
                                        .padding()
                                        .background(bg.opacity(0.8))
                                        .cornerRadius(20)
                                }
                            }
                            .padding()
                        }
                    }
                #else
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Scanner is available on iOS")
                            .font(.headline)
                    }
                #endif
            }
            .navigationTitle("Scanner")
            .sheet(isPresented: $showScanner) {
                #if os(iOS)
                    DocumentScannerView { images in
                        scannedImages.append(contentsOf: images)
                        Task { await runOCR() }
                    }
                #else
                    EmptyView()
                #endif
            }
        }
        .applyAppTheme()
    }
}

#if os(iOS)
    // MARK: - VisionKit Wrapper
    struct DocumentScannerView: UIViewControllerRepresentable {
        var onCompletion: ([UIImage]) -> Void

        func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
            let scanner = VNDocumentCameraViewController()
            scanner.delegate = context.coordinator
            return scanner
        }

        func updateUIViewController(
            _ uiViewController: VNDocumentCameraViewController, context: Context
        ) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(onCompletion: onCompletion)
        }

        class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
            var onCompletion: ([UIImage]) -> Void

            init(onCompletion: @escaping ([UIImage]) -> Void) {
                self.onCompletion = onCompletion
            }

            func documentCameraViewController(
                _ controller: VNDocumentCameraViewController,
                didFinishWith scan: VNDocumentCameraScan
            ) {
                var images: [UIImage] = []
                for i in 0..<scan.pageCount {
                    images.append(scan.imageOfPage(at: i))
                }
                onCompletion(images)
                controller.dismiss(animated: true)
            }

            func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController)
            {
                controller.dismiss(animated: true)
            }

            func documentCameraViewController(
                _ controller: VNDocumentCameraViewController, didFailWithError error: Error
            ) {
                print("Scanner error: \(error)")
                controller.dismiss(animated: true)
            }
        }
    }

    extension ScanView {
        fileprivate func runOCR() async {
            guard !scannedImages.isEmpty else { return }
            isRecognizing = true
            defer { isRecognizing = false }
            do {
                let text = try await TextRecognitionService.shared.recognizeText(
                    from: scannedImages)
                recognizedText = text
            } catch {
                recognizedText = ""
            }
        }

        fileprivate func extractWordsFromText() {
            extractedWords = []

            let lines = recognizedText.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                var term = ""
                var meaning = ""

                if trimmed.contains(": ") {
                    let parts = trimmed.components(separatedBy: ": ")
                    if parts.count >= 2 {
                        term = parts[0]
                        meaning = parts[1]
                    }
                } else if trimmed.contains("\t") {
                    let parts = trimmed.components(separatedBy: "\t")
                    if parts.count >= 2 {
                        term = parts[0]
                        meaning = parts[1]
                    }
                } else if trimmed.contains(",") {
                    let parts = trimmed.components(separatedBy: ",")
                    if parts.count >= 2 {
                        term = parts[0]
                        meaning = parts[1]
                    }
                }

                term = term.trimmingCharacters(in: .whitespacesAndNewlines)
                meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !term.isEmpty, !meaning.isEmpty else { continue }

                if !extractedWords.contains(where: { $0.term == term }) {
                    extractedWords.append(ExtractedWord(term: term, meaning: meaning))
                }
            }
        }

        fileprivate func addToWordbook() {
            var words: [WordbookEntry] = []
            if let data = UserDefaults.standard.data(forKey: "anki_hub_wordbook"),
                let decoded = try? JSONDecoder().decode([WordbookEntry].self, from: data)
            {
                words = decoded
            }

            for extracted in extractedWords {
                let entry = WordbookEntry(
                    id: UUID().uuidString,
                    term: extracted.term,
                    meaning: extracted.meaning,
                    hint: nil,
                    mastery: .new
                )
                if !words.contains(where: { $0.term == entry.term }) {
                    words.append(entry)
                }
            }

            if let data = try? JSONEncoder().encode(words) {
                UserDefaults.standard.set(data, forKey: "anki_hub_wordbook")
            }

            Task { @MainActor in
                SyncManager.shared.requestAutoSync()
            }
        }

        fileprivate func resetAll() {
            scannedImages = []
            recognizedText = ""
            extractedWords = []
            isRecognizing = false
        }
    }

#endif

// Preview removed for macOS compatibility
