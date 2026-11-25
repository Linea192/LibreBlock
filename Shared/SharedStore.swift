import Foundation

/// Storage locations shared by the app and its extensions.
///
/// Design note: with a free Apple developer account, App Groups are not
/// provisioned. The extensions therefore ship with **precompiled default
/// rules** (DefaultRules.swift, generated at build time from the bundled
/// lists) and read the shared container only when it exists. The app always
/// writes to the container when available, so paid accounts get live rule
/// updates while free accounts still get working defaults.
public enum SharedStore {
    public static let appGroupID = "group.org.libreblock.shared"

    /// True when the App Group container is provisioned (paid account or
    /// simulator with groups enabled).
    public static var isAppGroupAvailable: Bool {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    /// Directory for compiled rule JSON and cached remote lists. Falls back
    /// to per-process storage when no App Group is present.
    public static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LibreBlock", isDirectory: true)
    }

    /// Compiled rule file for a group, written by the app, read by extensions.
    public static func rulesURL(for group: BlockerGroup) -> URL {
        containerURL.appendingPathComponent(group.fileName)
    }

    /// Cache location for a downloaded remote list.
    public static func cacheURL(for listID: String) -> URL {
        containerURL.appendingPathComponent("lists/\(listID).txt")
    }

    /// A bundled built-in filter list shipped inside the app/extension.
    public static func bundledDataURL(for listID: String) -> URL? {
        Bundle.main.url(forResource: "filters/\(listID)", withExtension: "txt")
    }

    /// UserDefaults suite shared with the extensions when available.
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
