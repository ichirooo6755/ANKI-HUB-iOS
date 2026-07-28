import SwiftUI

#if os(iOS)
import UIKit

enum ScanRegionKind: String, CaseIterable, Identifiable {
    case question
    case answer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .question: return "問題領域"
        case .answer: return "答え領域"
        }
    }

    var color: Color {
        switch self {
        case .question: return .blue
        case .answer: return .green
        }
    }
}

/// スキャン画像上で問題/答えの矩形領域を選択するビュー（正規化座標 0...1）
struct ImageRegionSelectorView: View {
    let image: UIImage
    @Binding var questionRect: CGRect
    @Binding var answerRect: CGRect
    @Binding var activeRegion: ScanRegionKind

    @State private var dragOriginRect: CGRect?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("領域", selection: $activeRegion) {
                ForEach(ScanRegionKind.allCases) { region in
                    Text(region.label).tag(region)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                presetButton("上半分→問題", region: .question) {
                    questionRect = CGRect(x: 0.03, y: 0.02, width: 0.94, height: 0.45)
                }
                presetButton("下半分→答え", region: .answer) {
                    answerRect = CGRect(x: 0.03, y: 0.48, width: 0.94, height: 0.45)
                }
            }
            .font(.caption.weight(.semibold))

            GeometryReader { geo in
                let frame = aspectFitFrame(imageSize: image.size, in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    regionOverlay(for: questionRect, kind: .question, in: frame)
                    regionOverlay(for: answerRect, kind: .answer, in: frame)

                    if activeRegion == .question {
                        regionOverlay(for: questionRect, kind: .question, in: frame, emphasized: true)
                            .gesture(dragGesture(for: .question, in: frame))
                    } else {
                        regionOverlay(for: answerRect, kind: .answer, in: frame, emphasized: true)
                            .gesture(dragGesture(for: .answer, in: frame))
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("選択中の領域をドラッグして位置を調整できます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func presetButton(_ title: String, region: ScanRegionKind, action: @escaping () -> Void) -> some View {
        Button {
            activeRegion = region
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func regionOverlay(
        for normalized: CGRect,
        kind: ScanRegionKind,
        in frame: CGRect,
        emphasized: Bool = false
    ) -> some View {
        let rect = denormalizedRect(normalized, in: frame)
        return RoundedRectangle(cornerRadius: 6)
            .stroke(kind.color.opacity(emphasized ? 1 : 0.55), lineWidth: emphasized ? 3 : 1.5)
            .background(kind.color.opacity(emphasized ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 6))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(emphasized)
    }

    private func dragGesture(for kind: ScanRegionKind, in frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragOriginRect == nil {
                    dragOriginRect = kind == .question ? questionRect : answerRect
                }
                guard let start = dragOriginRect else { return }
                var rect = start
                rect.origin.x = clamp(
                    start.origin.x + value.translation.width / frame.width,
                    min: 0,
                    max: 1 - rect.width
                )
                rect.origin.y = clamp(
                    start.origin.y + value.translation.height / frame.height,
                    min: 0,
                    max: 1 - rect.height
                )
                if kind == .question {
                    questionRect = rect
                } else {
                    answerRect = rect
                }
            }
            .onEnded { _ in
                dragOriginRect = nil
            }
    }

    private func aspectFitFrame(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2
        )
        return CGRect(origin: origin, size: size)
    }

    private func denormalizedRect(_ normalized: CGRect, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + normalized.origin.x * frame.width,
            y: frame.minY + normalized.origin.y * frame.height,
            width: normalized.width * frame.width,
            height: normalized.height * frame.height
        )
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
#endif
