//
//  SecureURL.swift
//  Parent Chat
//
//  Helpers that reject non-HTTPS URLs at construction time. Used everywhere
//  the app renders user-supplied media URLs (post images, profile images)
//  so a tampered Firestore doc can't trick AsyncImage into loading an
//  insecure (HTTP) endpoint and exposing the user to MITM.
//

import Foundation

extension URL {
    /// Returns a URL only if the string parses AND uses the HTTPS scheme.
    /// Returns nil for HTTP, file://, data:, javascript:, or malformed input.
    static func httpsOnly(_ string: String?) -> URL? {
        guard let string,
              let url = URL(string: string),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
