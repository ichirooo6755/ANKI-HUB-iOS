import SwiftUI

#if os(iOS)
    import VisionKit
    import UIKit
#endif

enum ScanHubMode: String, CaseIterable, Identifiable {
    case camera
    case paper
    case sessions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "カメラ"
        case .paper: return "紙の単語帳"
        case .sessions: return "問題集"
        }
    }
}

/// スキャン・OCR・問題集作成の統合ハブ（統合 C）
struct ScanView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var sessionManager = ScanSessionManager.shared

    let startScanning: Bool
    let initialMode: ScanHubMode

    @State private var mode: ScanHubMode
    @State private var showScanner = false
    @State private var showScannerUnsupportedAlert = false
    @State private var didAutoStartScanner = false
    @State private var showSaveSuccess = false

    #if os(iOS)
        @State private var scannedImages: [UIImage] = []
        @State private var recognizedText: String = ""
        @State private var extractedWords: [ExtractedWord] = []
        @State private var extractedBlanks: [String] = []
        @State private var isRecognizing: Bool = false
        @State private var questionText: String = ""
        @State private var answerText: String = ""
        @State private var selectedImageIndex: Int = 0
        @State private var questionRect: CGRect = CGRect(x: 0.03, y: 0.02, width: 0.94, height: 0.45)
        @State private var answerRect: CGRect = CGRect(x: 0.03, y: 0.48, width: 0.94, height: 0.45)
        @State private var activeRegion: ScanRegionKind = .question
    #endif

    @State private var sessionTitle: String = ""
    // 一時非表示: temp/hide-english-kobun-3days。main に戻せば再表示
    @State private var sessionSubject: Subject = Subject.allStudySubjects.first ?? .seikei

    struct ExtractedWord: Identifiable {
        let id = UUID()
        let term: String
        let meaning: String
    }

    init(startScanning: Bool = false, initialMode: ScanHubMode = .camera) {
        self.startScanning = startScanning
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                VStack(spacing: 0) {
                    Picker("モード", selection: $mode) {
                        ForEach(ScanHubMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    switch mode {
                    case .camera:
                        #if os(iOS)
                            cameraScanContent
                        #else
                            Text("iOS で利用できます")
                                .foregroundStyle(theme.secondaryText)
                        #endif
                    case .paper:
                        PaperWordbookSyncContent()
                    case .sessions:
                        sessionsContent
                    }
                }
            }
            .navigationTitle("スキャン & 問題集")
            .alert("スキャンできません", isPresented: $showScannerUnsupportedAlert) {
                Button("OK") {}
            } message: {
                Text("この端末ではスキャン機能が利用できません。実機(iPhone/iPad)でお試しください。")
            }
            .alert("問題集に保存しました", isPresented: $showSaveSuccess) {
                Button("OK") {}
            }
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
        .onAppear {
            sessionManager.load()
            attemptAutoStart()
        }
    }

    // MARK: - Sessions list

    private var sessionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sessionManager.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("問題集がありません", systemImage: "folder")
                    } description: {
                        Text("カメラタブでスキャンし、問題文・答えを入力して保存してください。")
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(sessionManager.sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.title)
                                    .font(.headline)
                                    .foregroundStyle(theme.primaryText)
                                Spacer()
                                Text("\(session.vocabulary.count)問")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            if let subject = Subject(rawValue: session.subjectRaw) {
                                Text(subject.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            ForEach(session.vocabulary.prefix(3)) { item in
                                Text("・\(item.term)")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(1)
                            }
                            if session.vocabulary.count > 3 {
                                Text("他 \(session.vocabulary.count - 3) 問…")
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                        .contextMenu {
                            Button(role: .destructive) {
                                sessionManager.deleteSession(session.id)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    #if os(iOS)
        @ViewBuilder
        private var cameraScanContent: some View {
            if scannedImages.isEmpty {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "doc.text.viewfinder")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)

                    Text("単語帳・問題集をスキャン")
                        .font(.title2.bold())
                        .foregroundStyle(theme.primaryText)

                    Text("撮影後に OCR で文字起こしし、\n問題文と答えを分けて問題集に保存できます。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.horizontal)

                    Button {
                        openScanner()
                    } label: {
                        let bg = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                        Label("スキャン開始", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(theme.onColor(for: bg))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(bg, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                            ForEach(Array(scannedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                                    .overlay {
                                        if index == selectedImageIndex {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.accentColor, lineWidth: 3)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedImageIndex = index
                                    }
                            }
                        }

                        if selectedImageIndex < scannedImages.count {
                            regionSelectionSection(image: scannedImages[selectedImageIndex])
                        }

                        ocrSection
                        qaSection
                        actionButtons
                        extractedResultsSection
                        saveSessionSection

                        Spacer(minLength: 80)
                    }
                    .padding(.top)
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 12) {
                        Button {
                            openScanner()
                        } label: {
                            Label("追加", systemImage: "plus")
                                .font(.headline)
                                .foregroundStyle(theme.primaryText)
                                .padding()
                                .liquidGlass()
                        }

                        Button {
                            resetAll()
                        } label: {
                            let bg = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                            Label("リセット", systemImage: "trash")
                                .font(.headline)
                                .foregroundStyle(theme.onColor(for: bg))
                                .padding()
                                .background(bg.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding()
                }
            }
        }

        private func regionSelectionSection(image: UIImage) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("領域選択（ページ \(selectedImageIndex + 1)）")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                ImageRegionSelectorView(
                    image: image,
                    questionRect: $questionRect,
                    answerRect: $answerRect,
                    activeRegion: $activeRegion
                )
            }
            .padding(.horizontal)
        }

        private var ocrSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("OCR 全文")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                TextEditor(text: $recognizedText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }

        private var qaSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("問題文 / 答え")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                HStack {
                    Button("全文→問題") { questionText = recognizedText }
                    Button("全文→答え") { answerText = recognizedText }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)

                Text("問題文")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                TextEditor(text: $questionText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))

                Text("答え")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                TextEditor(text: $answerText)
                    .frame(minHeight: 60)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }

        private var actionButtons: some View {
            VStack(spacing: 12) {
                if isRecognizing {
                    ProgressView("OCR中...")
                }

                Button {
                    Task { await runOCR() }
                } label: {
                    actionButtonLabel("全文OCR", icon: "text.viewfinder", role: .mastered)
                }
                .disabled(isRecognizing)

                Button {
                    Task { await runRegionOCR() }
                } label: {
                    actionButtonLabel("領域OCR（問題/答え）", icon: "viewfinder.rectangular", role: .accent)
                }
                .disabled(isRecognizing)

                Button { extractBlanksFromText() } label: {
                    actionButtonLabel("空欄を抽出", icon: "square.dashed", role: .accent)
                }

                Button { extractWordsFromText() } label: {
                    actionButtonLabel("単語を抽出", icon: "wand.and.stars", role: .selection)
                }

                if !extractedWords.isEmpty {
                    Button { addToWordbook() } label: {
                        actionButtonLabel(
                            "単語帳に追加 (\(extractedWords.count))",
                            icon: "bookmark.fill",
                            role: .primary
                        )
                    }
                }
            }
            .padding(.horizontal)
        }

        private var extractedResultsSection: some View {
            Group {
                if !extractedBlanks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("空欄候補")
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)
                        ForEach(extractedBlanks, id: \.self) { b in
                            Text(b)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)
                }

                if !extractedWords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("抽出結果")
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)
                        ForEach(extractedWords) { w in
                            VStack(alignment: .leading) {
                                Text(w.term).font(.headline).foregroundStyle(theme.primaryText)
                                Text(w.meaning).font(.caption).foregroundStyle(theme.secondaryText)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }

        private var saveSessionSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("問題集として保存")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                TextField("チャプター名（例: 英単語 p.12）", text: $sessionTitle)
                    .textFieldStyle(.roundedBorder)

                Picker("教科", selection: $sessionSubject) {
                    ForEach(Subject.allStudySubjects) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    saveCurrentAsSession()
                } label: {
                    actionButtonLabel("問題集に保存", icon: "folder.badge.plus", role: .primary)
                }
                .disabled(!canSaveSession)
            }
            .padding(.horizontal)
        }

        private var canSaveSession: Bool {
            let q = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return !title.isEmpty && (!q.isEmpty || !extractedWords.isEmpty) && (!a.isEmpty || !extractedWords.isEmpty)
        }

        private enum ActionRole { case primary, accent, mastered, selection, weak }

        private func actionButtonLabel(_ title: String, icon: String, role: ActionRole) -> some View {
            let bg: Color = {
                switch role {
                case .primary: return theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                case .accent: return theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                case .mastered: return theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
                case .selection: return theme.currentPalette.color(.selection, isDark: theme.effectiveIsDark)
                case .weak: return theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                }
            }()
            return Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(theme.onColor(for: bg))
                .frame(maxWidth: .infinity)
                .padding()
                .background(bg, in: RoundedRectangle(cornerRadius: 12))
        }

        private func saveCurrentAsSession() {
            var items: [ScanVocabEntry] = extractedWords.map {
                ScanVocabEntry(term: $0.term, meaning: $0.meaning)
            }

            let q = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty, !a.isEmpty {
                items.insert(ScanVocabEntry(term: q, meaning: a), at: 0)
            }

            guard !items.isEmpty else { return }
            sessionManager.saveSession(
                title: sessionTitle,
                subject: sessionSubject,
                vocabulary: items
            )
            showSaveSuccess = true
            mode = .sessions
        }
    #endif

    private func attemptAutoStart() {
        guard startScanning, !didAutoStartScanner else { return }
        didAutoStartScanner = true
        mode = .camera
        #if os(iOS)
            DispatchQueue.main.async { openScanner() }
        #endif
    }

    private func openScanner() {
        #if os(iOS)
            if VNDocumentCameraViewController.isSupported {
                showScanner = true
            } else {
                showScannerUnsupportedAlert = true
            }
        #else
            showScannerUnsupportedAlert = true
        #endif
    }
}

#if os(iOS)
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

            func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
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
                recognizedText = try await TextRecognitionService.shared.recognizeText(from: scannedImages)
                extractBlanksFromText()
            } catch {
                recognizedText = ""
            }
        }

        fileprivate func runRegionOCR() async {
            guard selectedImageIndex < scannedImages.count else { return }
            isRecognizing = true
            defer { isRecognizing = false }
            let image = scannedImages[selectedImageIndex]
            do {
                let q = try await TextRecognitionService.shared.recognizeText(
                    from: image,
                    normalizedRect: questionRect
                )
                let a = try await TextRecognitionService.shared.recognizeText(
                    from: image,
                    normalizedRect: answerRect
                )
                questionText = q.trimmingCharacters(in: .whitespacesAndNewlines)
                answerText = a.trimmingCharacters(in: .whitespacesAndNewlines)
                if !questionText.isEmpty || !answerText.isEmpty {
                    recognizedText = [questionText, answerText]
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n---\n")
                }
                extractBlanksFromText()
            } catch {
                questionText = ""
                answerText = ""
            }
        }

        fileprivate func extractBlanksFromText() {
            let lines = recognizedText.components(separatedBy: .newlines)
            var blanks: [String] = []

            func add(_ s: String) {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !blanks.contains(t) else { return }
                blanks.append(t)
            }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if trimmed.contains("□") || trimmed.contains("＿") || trimmed.contains("__") {
                    add(trimmed)
                } else if trimmed.contains("（　") || trimmed.contains("( ") {
                    add(trimmed)
                }
            }
            extractedBlanks = blanks
        }

        fileprivate func extractWordsFromText() {
            extractedWords = []
            for line in recognizedText.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                var term = ""
                var meaning = ""
                if trimmed.contains(": ") {
                    let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        term = parts[0].trimmingCharacters(in: .whitespaces)
                        meaning = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                } else if trimmed.contains("\t") {
                    let parts = trimmed.components(separatedBy: "\t")
                    if parts.count >= 2 { term = parts[0]; meaning = parts[1] }
                } else if trimmed.contains(",") {
                    let parts = trimmed.components(separatedBy: ",")
                    if parts.count >= 2 { term = parts[0]; meaning = parts[1] }
                }
                guard !term.isEmpty, !meaning.isEmpty else { continue }
                if !extractedWords.contains(where: { $0.term == term }) {
                    extractedWords.append(ExtractedWord(term: term, meaning: meaning))
                }
            }
        }

        fileprivate func addToWordbook() {
            sessionManager.saveSession(
                title: sessionTitle.isEmpty ? "スキャン \(Date().formatted(date: .abbreviated, time: .omitted))" : sessionTitle,
                subject: sessionSubject,
                vocabulary: extractedWords.map { ScanVocabEntry(term: $0.term, meaning: $0.meaning) }
            )
            showSaveSuccess = true
        }

        fileprivate func resetAll() {
            scannedImages = []
            recognizedText = ""
            extractedWords = []
            extractedBlanks = []
            questionText = ""
            answerText = ""
            selectedImageIndex = 0
            questionRect = CGRect(x: 0.03, y: 0.02, width: 0.94, height: 0.45)
            answerRect = CGRect(x: 0.03, y: 0.48, width: 0.94, height: 0.45)
            activeRegion = .question
            isRecognizing = false
        }
    }
#endif
