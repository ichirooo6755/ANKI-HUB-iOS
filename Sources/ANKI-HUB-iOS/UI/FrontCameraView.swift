import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit
#endif

struct FrontCameraView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

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
                Text("フロントカメラ")
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
                    FrontCameraPreview(session: cameraModel.session)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(border.opacity(0.4), lineWidth: 1)
                        )
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

                Text("ロック画面のコントロールから起動できます")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 52))
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
                .font(.system(size: 52))
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

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
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
