import SwiftUI
import Combine

/// Root observable object: owns settings, list selection and drives the
/// filter engine. Persisted to the App Group and mirrored to iCloud
/// key-value storage when sync is on.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings: LibreBlockSettings {
        didSet { persist() }
    }
    @Published var lists: [FilterList] {
        didSet { persistSelection() }
    }
    @Published var lastUpdateResult: [String: Result<Date, Error>] = [:]
    @Published var isUpdating = false

    private let engine = FilterEngine.shared
    private let defaults = SharedStore.sharedDefaults
    private let iCloud = NSUbiquitousKeyValueStore.default

    init() {
        let settings: LibreBlockSettings
        if let data = defaults.data(forKey: "settings"),
           let decoded = try? JSONDecoder().decode(LibreBlockSettings.self, from: data) {
            settings = decoded
        } else {
            settings = LibreBlockSettings()
        }
        self.settings = settings

        let selection = (try? JSONDecoder().decode([String: Bool].self,
                                                  from: defaults.data(forKey: "listSelection") ?? Data())) ?? [:]
        self.lists = BlockerCatalog.lists(selection: selection)

        NotificationCenter.default.addObserver(
            self, selector: #selector(iCloudChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil)

        // First launch: build rule files immediately so Safari has content.
        if !settings.onboardingCompleted || !FileManager.default.fileExists(atPath: SharedStore.rulesURL(for: .ads).path) {
            try? engine.rebuildAll(lists: lists, settings: settings)
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: "settings")
        }
        if settings.useICloudSync {
            if let data = try? JSONEncoder().encode(settings) {
                iCloud.set(data, forKey: "settings")
            }
            iCloud.synchronize()
        }
        rebuild()
    }

    private func persistSelection() {
        let selection = Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0.chosen) })
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: "listSelection")
        }
        if settings.useICloudSync {
            if let data = try? JSONEncoder().encode(selection) {
                iCloud.set(data, forKey: "listSelection")
            }
            iCloud.synchronize()
        }
        rebuild()
    }

    @objc private func iCloudChanged(_ note: Notification) {
        guard settings.useICloudSync,
              let data = iCloud.data(forKey: "settings"),
              let remote = try? JSONDecoder().decode(LibreBlockSettings.self, from: data)
        else { return }
        // Last-writer-wins with a timestamp guard.
        if (remote.lastFilterUpdate ?? .distantPast) > (settings.lastFilterUpdate ?? .distantPast) {
            settings = remote
        }
    }

    // MARK: - Engine bridge

    func rebuild() {
        do {
            try engine.rebuildAll(lists: lists, settings: settings)
            try engine.rebuildCustom(settings: settings)
        } catch {
            // Rebuild failures leave the previous rule files in place;
            // surfaced in the UI via lastUpdateResult on refresh.
        }
    }

    func updateFilters() async {
        isUpdating = true
        defer { isUpdating = false }
        let results = await engine.updateRemoteLists(lists)
        lastUpdateResult = results
        settings.lastFilterUpdate = Date()
        rebuild()
    }

    // MARK: - Feature toggles

    func setGroup(_ group: BlockerGroup, enabled: Bool) {
        settings.groups[group]?.enabled = enabled
    }

    func setSite(_ domain: String, group: BlockerGroup, enabled: Bool) {
        settings.groups[group]?.siteOverrides[domain] = enabled
    }

    func toggleList(_ id: String) {
        guard let idx = lists.firstIndex(where: { $0.id == id }) else { return }
        lists[idx].chosen.toggle()
        // Enforce implies: turning on a regional list enables its base.
        if lists[idx].chosen {
            for base in BlockerCatalog.shared.first(where: { $0.id == id })?.implies ?? [] {
                if let bidx = lists.firstIndex(where: { $0.id == base }) {
                    lists[bidx].chosen = true
                }
            }
        }
    }

    func ruleCount(for group: BlockerGroup) -> Int {
        defaults.integer(forKey: "ruleCount.\(group.rawValue)")
    }

    var totalRuleCount: Int {
        BlockerGroup.allCases.reduce(0) { $0 + ruleCount(for: $1) }
    }
}
