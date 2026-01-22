import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit
#endif

struct FrontCameraView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var zoomFactor: CGFloat = 1.0
    @State private var previewBrightness: Double = 0.0
    @State private var showGrid: Bool = false
    @State private var isMirrored: Bool = true

    #if os(iOS)
    @StateObject private var cameraModel = FrontCameraSessionModel()
    #endif

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    #if os(iOS)
                    cameraContent
                    #else
                    unsupportedContent
                    #endif
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .padding(.top, proxy.safeAreaInsets.top + 8)
            }
            .overlay(alignment: .top) {
                topBar
                    .safeAreaPadding(.top, 8)
            }
            #if os(iOS)
            .onAppear {
                cameraModel.start()
            }
            .onDisappear {
                cameraModel.stop()
            }
            #endif
            .applyAppTheme()
        }
    }

    #if os(iOS)
    private var controlPanel: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
        let zoomText = Text("\(zoomFactor, specifier: "%.1f")×")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(theme.primaryText)
        let brightnessText = Text("\(previewBrightness, specifier: "%.2f")")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(theme.primaryText)

        return VStack(alignment: .leading, spacing: 14) {
            Text("コントロール")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent {
                    zoomText
                } label: {
                    Label("ズーム", systemImage: "plus.magnifyingglass")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
                Slider(value: $zoomFactor, in: 1.0...1.8, step: 0.1)
                    .tint(accent)
                    .accessibilityValue(Text("\(zoomFactor, specifier: "%.1f")倍"))
            }

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent {
                    brightnessText
                } label: {
                    Label("明るさ", systemImage: "sun.max.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
                Slider(value: $previewBrightness, in: -0.2...0.35, step: 0.05)
                    .tint(accent)
                    .accessibilityValue(Text("\(previewBrightness, specifier: "%.2f")"))
            }

            Toggle(isOn: $showGrid) {
                Label("ガイドライン", systemImage: "square.grid.3x3")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
            .tint(accent)

            Toggle(isOn: $isMirrored) {
                Label("左右反転", systemImage: "arrow.left.and.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
            }
            .tint(accent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.86 : 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(border.opacity(0.5), lineWidth: 1)
        )
    }

    private var mirrorGridOverlay: some View {
        GeometryReader { proxy in
            let lineColor = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
                .opacity(0.45)
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                let v1 = width / 3
                let v2 = width * 2 / 3
                let h1 = height / 3
                let h2 = height * 2 / 3
                path.move(to: CGPoint(x: v1, y: 0))
                path.addLine(to: CGPoint(x: v1, y: height))
                path.move(to: CGPoint(x: v2, y: 0))
                path.addLine(to: CGPoint(x: v2, y: height))
                path.move(to: CGPoint(x: 0, y: h1))
                path.addLine(to: CGPoint(x: width, y: h1))
                path.move(to: CGPoint(x: 0, y: h2))
                path.addLine(to: CGPoint(x: width, y: h2))
            }
            .stroke(lineColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .allowsHitTesting(false)
    }
    #endif

    private var topBar: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)

        return HStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .foregroundStyle(theme.primaryText)
                .frame(width: 34, height: 34)
                .background(surface.opacity(0.8))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("ミラー")
                    .font(.headline)
                Text("ロック画面コントロール対応")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surface.opacity(theme.effectiveIsDark ? 0.86 : 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(border.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    #if os(iOS)
    private var cameraContent: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let border = theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)

        return VStack(spacing: 16) {
            if cameraModel.authorizationStatus == .authorized {
                ZStack(alignment: .bottomLeading) {
                    FrontCameraPreview(session: cameraModel.session, isMirrored: isMirrored)
                        .scaleEffect(zoomFactor)
                        .brightness(previewBrightness)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(border.opacity(0.4), lineWidth: 1)
                        )
                        .overlay {
                            if showGrid {
                                mirrorGridOverlay
                            }
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ロック画面のコントロールから起動できます")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)

                    Text("アプリと同じUIでミラーを表示します")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)

                    Text("ミラー表示のため撮影・保存は行いません")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                controlPanel
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)

                    Text("カメラ権限が必要です")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    Text("設定 > プライバシー > カメラ から許可してください")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)

                    Button {
                        cameraModel.requestAccess()
                    } label: {
                        Label("カメラを許可", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(theme.onColor(for: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(border.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }
    #else
    private var unsupportedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("iOS端末でのみ利用できます")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    #endif
}

#if os(iOS)
final class FrontCameraSessionModel: ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "front.camera.session")
    private var isConfigured = false

    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            DispatchQueue.main.async {
                self?.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                self?.start()
            }
        }
    }

    func start() {
        if authorizationStatus == .notDetermined {
            requestAccess()
            return
        }
        guard authorizationStatus == .authorized else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
        isConfigured = true
    }
}

struct FrontCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        applyMirror(to: view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        applyMirror(to: uiView.videoPreviewLayer)
    }

    private func applyMirror(to layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection, connection.isVideoMirroringSupported else {
            return
        }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#endif
