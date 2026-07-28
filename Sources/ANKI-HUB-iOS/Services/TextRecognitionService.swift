import Foundation

#if os(iOS)
import UIKit
import Vision
import ImageIO

final class TextRecognitionService {
    static let shared = TextRecognitionService()

    private init() {}

    func recognizeText(from images: [UIImage]) async throws -> String {
        var combined: [String] = []
        for image in images {
            let text = try await recognizeText(from: image)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                combined.append(text)
            }
        }
        return combined.joined(separator: "\n\n")
    }

    /// 正規化矩形（0...1）で画像を切り出して OCR
    func recognizeText(from image: UIImage, normalizedRect: CGRect) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }

        let clamped = CGRect(
            x: max(0, min(normalizedRect.origin.x, 1)),
            y: max(0, min(normalizedRect.origin.y, 1)),
            width: max(0.05, min(normalizedRect.width, 1)),
            height: max(0.05, min(normalizedRect.height, 1))
        )

        let pixelRect = CGRect(
            x: clamped.origin.x * CGFloat(cgImage.width),
            y: clamped.origin.y * CGFloat(cgImage.height),
            width: clamped.width * CGFloat(cgImage.width),
            height: clamped.height * CGFloat(cgImage.height)
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return "" }
        return try await recognizeText(from: UIImage(cgImage: cropped))
    }

    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let strings: [String] = ((request.results as? [VNRecognizedTextObservation]) ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }

                continuation.resume(returning: strings.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ja-JP", "en-US"]

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: cgImageOrientation(from: image.imageOrientation),
                options: [:]
            )
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
#endif
