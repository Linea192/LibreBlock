import Foundation

/// Assembles, compiles and installs the rule sets for all six blocker
/// groups. Runs inside the app; extensions only read the compiled JSON.
public final class FilterEngine: @unchecked Sendable {
    public static let shared = FilterEngine()

    private let compiler = RuleCompiler()
    private let defaults = SharedStore.sharedDefaults

    private var cacheDir: URL {
        SharedStore.containerURL.appendingPathComponent("lists", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Entry points

    /// Rebuilds every group's rule file from current settings + caches.
    /// Called after any setting change and after each filter update.
    public func rebuildAll(lists: [FilterList], settings: LibreBlockSettings) throws {
        // The Custom group is owned by rebuildCustom; skip it here so the
        // two writers never clobber each other.
        for group in BlockerGroup.allCases where group != .custom {
            try rebuild(group: group, lists: lists, settings: settings)
        }
        try rebuildCustom(settings: settings)
        defaults.set(Date(), forKey: "lastRebuild")
    }

    /// Rebuilds one group. A disabled group writes an empty rule array so
    /// Safari's extension toggle and our master switch stay in sync.
    public func rebuild(group: BlockerGroup, lists: [FilterList], settings: LibreBlockSettings) throws {
        let groupSettings = settings.groups[group] ?? GroupSettings()
        let selected = lists.filter { $0.group == group && $0.chosen }

        var combined = ""
        if groupSettings.enabled {
            for list in selected {
                combined += listText(for: list)
                combined += "\n"
            }
            // Site overrides: allow-listed domains first, then per-site blocks.
            let (allowed, blocked) = siteRules(from: groupSettings.siteOverrides)
            combined += allowed + "\n" + blocked
        }

        let compiled = try compiler.compile(listText: combined)
        try compiled.data.write(to: SharedStore.rulesURL(for: group), options: .atomic)
        defaults.set(compiled.count, forKey: "ruleCount.\(group.rawValue)")
    }

    /// Builds custom rules into the Custom group's file.
    public func rebuildCustom(settings: LibreBlockSettings) throws {
        var text = ""
        for rule in settings.customRules {
            let domains = rule.domains.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let pattern = rule.pattern.isEmpty ? "*" : rule.pattern
            let prefix = rule.action == .allow ? "@@" : ""
            if domains.isEmpty {
                text += prefix + pattern + "\n"
            } else {
                text += prefix + pattern
                    + "$domain=" + domains.joined(separator: "|") + "\n"
            }
        }
        let compiled = try compiler.compile(listText: text)
        try compiled.data.write(to: SharedStore.rulesURL(for: .custom), options: .atomic)
        defaults.set(compiled.count, forKey: "ruleCount.custom")
    }

    // MARK: - Updates

    /// Downloads the remote lists that are enabled and refreshes caches.
    /// - Returns: per-list outcome for UI reporting.
    @discardableResult
    public func updateRemoteLists(_ lists: [FilterList]) async -> [String: Result<Date, Error>] {
        await withCheckedContinuation { continuation in
            var results: [String: Result<Date, Error>] = [:]
            let remote = lists.filter { $0.chosen && $0.url != nil }

            let group = DispatchGroup()
            let lock = NSLock()

            for list in remote {
                guard let url = list.url else { continue }
                group.enter()
                let task = URLSession.shared.dataTask(with: url) { data, response, _ in
                    defer { group.leave() }
                    guard let data, !data.isEmpty,
                          let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode)
                    else {
                        lock.lock()
                        results[list.id] = .failure(UpdateError.badResponse)
                        lock.unlock()
                        return
                    }
                    do {
                        try FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
                        try data.write(to: SharedStore.cacheURL(for: list.id), options: .atomic)
                        lock.lock()
                        results[list.id] = .success(Date())
                        lock.unlock()
                    } catch {
                        lock.lock()
                        results[list.id] = .failure(error)
                        lock.unlock()
                    }
                }
                task.resume()
            }

            group.notify(queue: .main) {
                continuation.resume(returning: results)
            }
        }
    }

    public enum UpdateError: LocalizedError {
        case badResponse

        public var errorDescription: String? {
            switch self {
            case .badResponse: return "The filter list could not be downloaded."
            }
        }
    }

    // MARK: - Rule text sourcing

    func listText(for list: FilterList) -> String {
        let cached = SharedStore.cacheURL(for: list.id)
        if let data = try? Data(contentsOf: cached), !data.isEmpty {
            return String(decoding: data, as: UTF8.self)
        }
        if let bundled = SharedStore.bundledDataURL(for: list.id),
           let data = try? Data(contentsOf: bundled) {
            return String(decoding: data, as: UTF8.self)
        }
        // Remote-only list never downloaded: an empty string keeps the
        // other lists' rules intact instead of injecting a bogus pattern.
        return ""
    }

    private func siteRules(from overrides: [String: Bool]) -> (allowed: String, blocked: String) {
        var allowed = ""
        var blocked = ""
        for (domain, on) in overrides.sorted(by: { $0.key < $1.key }) {
            if on {
                blocked += "||\(domain)^\n"
            } else {
                allowed += "@@||\(domain)^\n"
            }
        }
        return (allowed, blocked)
    }
}
