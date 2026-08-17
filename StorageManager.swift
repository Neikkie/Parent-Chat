//
//  StorageManager.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import FirebaseStorage
import UIKit
import AVFoundation

@MainActor
class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage()
    
    private init() {}
    
    // Upload profile image
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImageData
        }
        
        let filename = "profile_\(userId).jpg"
        let storageRef = storage.reference().child("profiles/\(userId)/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // Upload image to Firebase Storage
    func uploadImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.invalidImageData
        }

        let filename = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("posts/\(userId)/images/\(filename)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw mapStorageError(error)
        }
    }
    
    // Upload video to Firebase Storage
    func uploadVideo(_ videoURL: URL, userId: String) async throws -> (videoURL: String, thumbnailURL: String) {
        let videoData = try Data(contentsOf: videoURL)
        
        let filename = "\(UUID().uuidString).mp4"
        let storageRef = storage.reference().child("posts/\(userId)/videos/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await storageRef.putDataAsync(videoData, metadata: metadata)
        let videoDownloadURL = try await storageRef.downloadURL()
        
        // Generate and upload thumbnail
        let thumbnail = try await generateVideoThumbnail(url: videoURL)
        let thumbnailURL = try await uploadImage(thumbnail, userId: userId)
        
        return (videoDownloadURL.absoluteString, thumbnailURL)
    }
    
    // Generate thumbnail from video
    private func generateVideoThumbnail(url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: StorageError.thumbnailGenerationFailed)
                    return
                }
                
                let image = UIImage(cgImage: cgImage)
                continuation.resume(returning: image)
            }
        }
    }
    
    // Delete media from Storage.
    // Firebase HTTPS download URLs contain a token query param that makes
    // reference(forURL:) unreliable for older uploads. Extract the object
    // path from the URL and build the reference directly instead.
    func deleteMedia(at url: String) async throws {
        let storageRef: StorageReference
        if url.hasPrefix("gs://") {
            storageRef = storage.reference(forURL: url)
        } else if let path = storagePathFromDownloadURL(url) {
            storageRef = storage.reference().child(path)
        } else {
            storageRef = storage.reference(forURL: url)
        }
        try await storageRef.delete()
    }

    // Extracts the object path from a Firebase Storage HTTPS download URL.
    // URL format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded-path}?alt=media&token=...
    // Uses percentEncodedPath so %2F (encoded slash in file path) is NOT decoded
    // before splitting — avoids ambiguity with real path separators.
    private func storagePathFromDownloadURL(_ urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              components.host?.contains("firebasestorage.googleapis.com") == true else { return nil }
        let parts = components.percentEncodedPath.components(separatedBy: "/o/")
        guard parts.count >= 2 else { return nil }
        // Rejoin in case the object path itself contains a literal "/o/"
        let encodedObjectPath = parts[1...].joined(separator: "/o/")
        return encodedObjectPath.removingPercentEncoding
    }

    private func mapStorageError(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == StorageErrorDomain,
           let code = StorageErrorCode(rawValue: nsError.code),
           code == .unauthorized {
            return StorageError.permissionDenied
        }
        return error
    }
}

enum StorageError: LocalizedError {
    case invalidImageData
    case thumbnailGenerationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Failed to process image data"
        case .thumbnailGenerationFailed:
            return "Failed to generate video thumbnail"
        case .permissionDenied:
            return "Upload blocked by Firebase Storage rules. Publish Storage rules for /posts/{userId}/... and ensure you are signed in."
        }
    }
}
