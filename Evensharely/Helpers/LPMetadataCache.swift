// LPMetadataCache.swift
import Foundation
@preconcurrency import LinkPresentation
import CryptoKit

/// Throttles concurrent async work.
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(value: Int) { self.value = value }

    func acquire() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            waiters.append(c)
        }
    }

    func release() {
        if waiters.isEmpty {
            value += 1
        } else {
            let c = waiters.removeFirst()
            c.resume()
        }
    }
}

final class LPMetadataCache {
    static let shared = LPMetadataCache()

    private let mem = NSCache<NSString, LPLinkMetadata>()
    private let semaphore = AsyncSemaphore(value: 2) // limit concurrent LP fetches
    private let fileQueue = DispatchQueue(label: "LPMetadataCache.files", qos: .utility)
    private let fm = FileManager.default
    private let baseURL: URL

    // Update this if you change your App Group
    private static let appGroupID = "group.com.marcsebes.evensharely"

    private init() {
        // Prefer the shared App Group so the extension + app see the same cache
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            baseURL = groupURL.appendingPathComponent("LPMetadataCache", isDirectory: true)
        } else {
            // Fallback (app only)
            let appSupport = try? fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            baseURL = (appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("LPMetadataCache", isDirectory: true)
        }

        // Create directory synchronously once
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)

        // Keep memory pressure in check
        mem.countLimit = 300
        mem.totalCostLimit = 50 * 1024 * 1024 // ~50 MB
    }

    /// Main entry: get metadata with caching + throttling.
    func metadata(for url: URL) async throws -> LPLinkMetadata {
        let key = url.absoluteString as NSString

        // 1) Fast memory hit
        if let cached = mem.object(forKey: key) { return cached }

        // 2) Try disk (off main)
        if let disk = await loadFromDisk(url: url) {
            mem.setObject(disk, forKey: key)
            return disk
        }

        // 3) Throttle network fetches globally
        await semaphore.acquire()
        // ensure release even if we early-return or throw
        defer { Task { await semaphore.release() } }

        // Double-check after waiting (another task may have fetched/saved)
        if let cached2 = mem.object(forKey: key) { return cached2 }
        if let disk2 = await loadFromDisk(url: url) {
            mem.setObject(disk2, forKey: key)
            return disk2
        }

        // 4) Fetch from LinkPresentation with a brand-new provider (one-shot)
        let metadata: LPLinkMetadata = try await withCheckedThrowingContinuation { cont in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { meta, err in
                if let err { cont.resume(throwing: err); return }
                cont.resume(returning: meta ?? LPLinkMetadata())
            }
        }

        // 5) Save + memoize
        mem.setObject(metadata, forKey: key)
        await saveToDisk(metadata, for: url)
        return metadata
    }

    // MARK: - File I/O (isolated to fileQueue)

    private func fileURL(for url: URL) -> URL {
        let h = hash(url.absoluteString)
        return baseURL.appendingPathComponent(h).appendingPathExtension("lpmeta")
    }

    private func hash(_ s: String) -> String {
        let d = SHA256.hash(data: Data(s.utf8))
        return d.map { String(format: "%02x", $0) }.joined()
    }

    private func saveToDisk(_ meta: LPLinkMetadata, for url: URL) async {
        let file = fileURL(for: url)
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            fileQueue.async {
                defer { c.resume() }
                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: meta,
                        requiringSecureCoding: true
                    )
                    try data.write(to: file, options: .atomic)
                } catch {
                    // Best-effort cache; ignore errors
                }
            }
        }
    }

    private func loadFromDisk(url: URL) async -> LPLinkMetadata? {
        let file = fileURL(for: url)
        return await withCheckedContinuation { (c: CheckedContinuation<LPLinkMetadata?, Never>) in
            fileQueue.async {
                guard let data = try? Data(contentsOf: file) else {
                    c.resume(returning: nil)
                    return
                }
                let obj = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: LPLinkMetadata.self,
                    from: data
                )
                c.resume(returning: obj)
            }
        }
        }
}
