import SwiftUI
import CryptoKit

#if os(macOS)
import AppKit
private typealias PlatformImage = NSImage
#else
import UIKit
private typealias PlatformImage = UIImage
#endif

/// Simple in-memory cache shared across secure image loaders.
private final class SecureImageCache {
    static let shared = SecureImageCache()
    private let cache = NSCache<NSString, PlatformImage>()
    private let diskQueue = DispatchQueue(label: "com.easyiptv.secureimagecache", qos: .utility)
    private let diskCacheURL: URL
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDir = caches.appendingPathComponent("SecureImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        diskCacheURL = cacheDir
    }
    
    func image(forKey key: String) -> PlatformImage? {
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        let fileURL = diskCacheURL.appendingPathComponent(key.sha256Filename)
        if let data = try? Data(contentsOf: fileURL), let platformImage = PlatformImage(data: data) {
            cache.setObject(platformImage, forKey: key as NSString)
            return platformImage
        }
        return nil
    }
    
    func insert(_ image: PlatformImage, data: Data, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
        let fileURL = diskCacheURL.appendingPathComponent(key.sha256Filename)
        diskQueue.async {
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("SecureImageCache disk write failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Replaces SwiftUI.AsyncImage but routes requests through NetworkManager so
/// SSL exceptions and caching logic behave consistently on all platforms.
struct SecureAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var renderedImage: Image?
    @State private var isLoading = false
    
    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let renderedImage {
                content(renderedImage)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let alreadyLoading = await MainActor.run { isLoading }
        if alreadyLoading { return }
        guard let url else {
            await MainActor.run { renderedImage = nil }
            return
        }
        
        let cacheKey = Self.cacheKey(for: url)
        if let cached = SecureImageCache.shared.image(forKey: cacheKey) {
            await MainActor.run {
                renderedImage = Image(platformImage: cached)
            }
            return
        }
        
        await MainActor.run { isLoading = true }
        defer {
            Task { await MainActor.run { isLoading = false } }
        }
        
        do {
            let data = try await NetworkManager.shared.fetchData(from: url)
            guard let platformImage = PlatformImage(data: data) else { return }
            SecureImageCache.shared.insert(platformImage, data: data, forKey: cacheKey)
            await MainActor.run {
                renderedImage = Image(platformImage: platformImage)
            }
        } catch {
            print("SecureAsyncImage error: \(error.localizedDescription)")
        }
    }
    
    private static func cacheKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.query = nil
        components.fragment = nil
        return components.string?.lowercased() ?? url.absoluteString
    }
}

private extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self = Image(nsImage: platformImage)
        #else
        self = Image(uiImage: platformImage)
        #endif
    }
}

private extension String {
    var sha256Filename: String {
        guard let data = self.data(using: .utf8) else { return self.replacingOccurrences(of: "/", with: "_") }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
