import AppIntents
import SwiftUI

/// Siri shortcuts via the modern App Intents framework.
/// Users can say "Enable blocking in LibreBlock", "Disable blocking in
/// LibreBlock" or "Update filters in LibreBlock".

struct EnableBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Blocking"
    static var description = IntentDescription("Turn on all LibreBlock blocking groups.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = SharedStore.sharedDefaults
        var settings = Self.loadSettings(from: defaults)
        for group in BlockerGroup.allCases {
            settings.groups[group]?.enabled = true
        }
        Self.save(settings, to: defaults)
        try FilterEngine.shared.rebuildAll(lists: BlockerCatalog.lists(selection: Self.selection(from: defaults)),
                                           settings: settings)
        return .result(dialog: "Blocking enabled across all six extensions.")
    }

    static func loadSettings(from defaults: UserDefaults) -> LibreBlockSettings {
        if let data = defaults.data(forKey: "settings"),
           let s = try? JSONDecoder().decode(LibreBlockSettings.self, from: data) {
            return s
        }
        return LibreBlockSettings()
    }

    static func selection(from defaults: UserDefaults) -> [String: Bool] {
        guard let data = defaults.data(forKey: "listSelection"),
              let sel = try? JSONDecoder().decode([String: Bool].self, from: data) else { return [:] }
        return sel
    }

    static func save(_ settings: LibreBlockSettings, to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: "settings")
        }
    }
}

struct DisableBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Blocking"
    static var description = IntentDescription("Turn off all LibreBlock blocking groups.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = SharedStore.sharedDefaults
        var settings = EnableBlockingIntent.loadSettings(from: defaults)
        for group in BlockerGroup.allCases {
            settings.groups[group]?.enabled = false
        }
        EnableBlockingIntent.save(settings, to: defaults)
        try FilterEngine.shared.rebuildAll(lists: BlockerCatalog.lists(selection: EnableBlockingIntent.selection(from: defaults)),
                                           settings: settings)
        return .result(dialog: "Blocking disabled. Rule files are now empty.")
    }
}

struct UpdateFiltersIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Filters"
    static var description = IntentDescription("Download the latest community filter lists.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = SharedStore.sharedDefaults
        let settings = EnableBlockingIntent.loadSettings(from: defaults)
        let lists = BlockerCatalog.lists(selection: EnableBlockingIntent.selection(from: defaults))
        let results = await FilterEngine.shared.updateRemoteLists(lists)
        try FilterEngine.shared.rebuildAll(lists: lists, settings: settings)

        let ok = results.values.filter { if case .success = $0 { true } else { false } }.count
        let failed = results.count - ok
        let dialog: String
        if results.isEmpty {
            dialog = "No remote lists are enabled; nothing to update."
        } else if failed == 0 {
            dialog = "Updated \(ok) filter lists."
        } else {
            dialog = "Updated \(ok) lists; \(failed) failed and kept their cached copies."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

/// Shows the three intents in the Shortcuts app under a single app entity.
struct LibreBlockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: EnableBlockingIntent(),
                   phrases: ["Enable blocking in \(.applicationName)"],
                   shortTitle: "Enable Blocking",
                   systemImageName: "checkmark.shield")
        AppShortcut(intent: DisableBlockingIntent(),
                   phrases: ["Disable blocking in \(.applicationName)"],
                   shortTitle: "Disable Blocking",
                   systemImageName: "shield.slash")
        AppShortcut(intent: UpdateFiltersIntent(),
                   phrases: ["Update filters in \(.applicationName)"],
                   shortTitle: "Update Filters",
                   systemImageName: "arrow.triangle.2.circlepath")
    }
}
