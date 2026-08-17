//
//  ImageModerationManager.swift
//  Parent Chat
//
//  On-device image moderation:
//   • Face detection (Vision) — child-safety: rejects photos with people
//   • Sensitive-content analysis (SensitiveContentAnalysis) — rejects nudity
//  Both run on-device — no network calls, no data leaves the device.
//

import Foundation
import UIKit
import Vision
import SensitiveContentAnalysis
import AVFoundation

enum ImageModerationManager {
    /// Returns the number of faces detected in the image.
    /// Runs the Vision request on a detached task so the main actor isn't blocked.
    static func faceCount(in image: UIImage) async -> Int {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return 0 }
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return 0
            }
            return request.results?.count ?? 0
        }.value
    }

    /// Convenience: returns true if any face was detected.
    static func containsAnyFace(_ image: UIImage) async -> Bool {
        await faceCount(in: image) > 0
    }

    /// True when the user's device has Sensitive Content Warnings enabled
    /// (Settings → Privacy & Security → Sensitive Content Warning).
    static var sensitiveAnalysisAvailable: Bool {
        SCSensitivityAnalyzer().analysisPolicy != .disabled
    }

    /// Returns true if Apple's on-device sensitive-content analyzer flags the
    /// image as containing nudity. Requires the user to have enabled the
    /// system-level "Sensitive Content Warnings" toggle. When disabled we log
    /// a warning (so debugging tells you why uploads aren't being scanned),
    /// and the face-detection + audit-log layers still apply.
    static func containsSensitiveContent(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else {
            print("⚠️ SCSensitivityAnalyzer disabled — user must enable Sensitive Content Warnings in iOS Settings for nudity scanning to run.")
            return false
        }

        do {
            let response = try await analyzer.analyzeImage(cgImage)
            return response.isSensitive
        } catch {
            print("⚠️ SCSensitivityAnalyzer failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Result of running all moderation checks on a single image.
    /// - `hasFace` is a soft flag: the UI should warn and require attestation, but not auto-reject.
    /// - `isSensitive` is a hard block: nudity / explicit content is never allowed.
    struct ModerationResult {
        let hasFace: Bool
        let isSensitive: Bool
        var shouldBlock: Bool { isSensitive }
        var requiresAttestation: Bool { hasFace && !isSensitive }
    }

    /// Runs both face detection and sensitive-content analysis in parallel.
    static func moderate(_ image: UIImage) async -> ModerationResult {
        async let face = containsAnyFace(image)
        async let sensitive = containsSensitiveContent(image)
        let (hasFace, isSensitive) = await (face, sensitive)
        return ModerationResult(hasFace: hasFace, isSensitive: isSensitive)
    }

    // MARK: - Video

    /// Generates a representative still (~1s in) from a video for previews and
    /// face detection. Returns nil if a frame can't be extracted.
    static func videoThumbnail(at url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Runs Apple's on-device sensitive-content analyzer across the video's
    /// frames. Same availability caveat as `containsSensitiveContent`.
    static func containsSensitiveVideo(at url: URL) async -> Bool {
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else {
            print("⚠️ SCSensitivityAnalyzer disabled — video not scanned for sensitive content.")
            return false
        }
        do {
            let handler = analyzer.videoAnalysis(forFileAt: url)
            let response = try await handler.hasSensitiveContent()
            return response.isSensitive
        } catch {
            print("⚠️ SCSensitivityAnalyzer video failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Result of moderating a picked video. Mirrors `ModerationResult` but also
    /// carries the extracted thumbnail (reused for the composer preview).
    struct VideoModerationResult {
        let thumbnail: UIImage?
        let hasFace: Bool
        let isSensitive: Bool
        var shouldBlock: Bool { isSensitive }
        var requiresAttestation: Bool { hasFace && !isSensitive }
    }

    /// Sensitive-content scan (hard block) runs across the whole video; face
    /// detection (attestation) runs on the extracted thumbnail frame — mirroring
    /// the image moderation flow.
    static func moderateVideo(at url: URL) async -> VideoModerationResult {
        async let sensitive = containsSensitiveVideo(at: url)
        let thumbnail = await videoThumbnail(at: url)
        let hasFace = thumbnail == nil ? false : await containsAnyFace(thumbnail!)
        let isSensitive = await sensitive
        return VideoModerationResult(thumbnail: thumbnail, hasFace: hasFace, isSensitive: isSensitive)
    }
}
