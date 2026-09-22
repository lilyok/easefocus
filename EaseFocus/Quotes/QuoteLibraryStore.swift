import Foundation

/// Bundled quotes plus optional remote extras from the public gist.
/// Remote rows only extend the library; they never remove bundled entries.
nonisolated enum QuoteLibraryStore {
    static let gistURL = URL(
        string: "https://gist.githubusercontent.com/lilyok/0c04ca5ca9032dde045cb699bedfae0b/raw/motivational-quotes.json"
    )!

    private static let cacheFileName = "easefocus-quotes-remote.json"
    private static let lock = NSLock()
    /// Protected by `lock`.
    nonisolated(unsafe) private static var remoteExtras: [LocalQuote] = []
    /// Protected by `lock`.
    nonisolated(unsafe) private static var didLoadCache = false

    static var library: [LocalQuote] {
        lock.lock()
        defer { lock.unlock() }
        loadCacheIfNeededLocked()
        return QuoteMerging.merge(base: LocalQuotes.all, remote: remoteExtras)
    }

    /// Loads any previously cached remote extras without hitting the network.
    static func prepareFromCache() {
        lock.lock()
        defer { lock.unlock() }
        loadCacheIfNeededLocked()
    }

    /// Fetches the public gist and merges new quotes into the on-device cache.
    /// Failures are ignored; bundled quotes always remain available.
    static func refreshFromRemote(
        session: URLSession = .shared,
        url: URL = gistURL
    ) async {
        prepareFromCache()
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }
            let remote = try QuoteCatalogParsing.quotes(from: data)
            guard !remote.isEmpty else {
                return
            }
            applyRemoteExtras(remote)
        } catch {
            // Offline / gist unavailable — keep bundled + prior cache.
        }
    }

    static func resetForTests() {
        lock.lock()
        defer { lock.unlock() }
        remoteExtras = []
        didLoadCache = false
    }

    // MARK: - Private

    private static func applyRemoteExtras(_ remote: [LocalQuote]) {
        lock.lock()
        defer { lock.unlock() }
        loadCacheIfNeededLocked()
        let mergedExtras = QuoteMerging.merge(base: remoteExtras, remote: remote)
        remoteExtras = mergedExtras
        didLoadCache = true
        saveCacheLocked(mergedExtras)
    }

    private static func loadCacheIfNeededLocked() {
        guard !didLoadCache else {
            return
        }
        didLoadCache = true
        guard let url = cacheURL(),
              let data = try? Data(contentsOf: url),
              let cached = try? QuoteCatalogParsing.quotes(from: data)
        else {
            remoteExtras = []
            return
        }
        remoteExtras = cached
    }

    private static func saveCacheLocked(_ quotes: [LocalQuote]) {
        guard let url = cacheURL(),
              let data = try? QuoteCatalogParsing.encode(quotes)
        else {
            return
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: [.atomic])
    }

    private static func cacheURL() -> URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: cacheFileName, directoryHint: .notDirectory)
    }
}
