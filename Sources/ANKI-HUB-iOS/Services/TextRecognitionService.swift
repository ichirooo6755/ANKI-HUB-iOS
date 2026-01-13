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
