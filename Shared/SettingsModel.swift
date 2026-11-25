import Foundation

/// One subscription (filter list) in the catalog. The catalog ships with the
/// app; `chosen` and `lastUpdated` are user state persisted via iCloud sync.
public struct FilterList: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case ads
        case privacy
        case social
        case safety
        case annoyances
        case regional
    }

    public let id: String
    public let name: String
    public let kind: Kind
    /// nil means the list ships inside the app bundle (built-in fallback).
    public let url: URL?
    public let group: BlockerGroup
    /// Extra lists that must be enabled together with this one (base lists).
    public let implies: [String]
    public var chosen: Bool
    public var lastUpdated: Date?

    public init(id: String,
                name: String,
                kind: Kind,
                url: URL? = nil,
                group: BlockerGroup,
                implies: [String] = [],
                chosen: Bool = false,
                lastUpdated: Date? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.url = url
        self.group = group
        self.implies = implies
        self.chosen = chosen
        self.lastUpdated = lastUpdated
    }
}

/// A single user-authored rule: "block (or allow) this pattern on these sites".
public struct CustomRule: Codable, Identifiable, Hashable, Sendable {
    public enum Action: String, Codable, Sendable {
        case block
        case allow
    }

    public var id: UUID
    public var action: Action
    /// Domain patterns separated by commas, e.g. "example.com, news.test".
    public var domains: String
    /// Plain text or wildcard pattern, e.g. "*/ads/*" or "doubleclick".
    public var pattern: String

    public init(id: UUID = UUID(),
                action: Action,
                domains: String,
                pattern: String) {
        self.id = id
        self.action = action
        self.domains = domains
        self.pattern = pattern
    }
}

/// Persisted state for one blocking group: master switch plus per-site overrides.
public struct GroupSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    /// Site overrides: domain -> on/off. A site set to false is allow-listed.
    public var siteOverrides: [String: Bool]

    public init(enabled: Bool = true, siteOverrides: [String: Bool] = [:]) {
        self.enabled = enabled
        self.siteOverrides = siteOverrides
    }
}

/// All persisted settings, kept in one Codable blob so iCloud sync is a
/// single key-value write.
public struct LibreBlockSettings: Codable, Equatable, Sendable {
    public var groups: [BlockerGroup: GroupSettings]
    public var customRules: [CustomRule]
    public var useICloudSync: Bool
    public var useAppLock: Bool
    public var lastFilterUpdate: Date?
    public var onboardingCompleted: Bool

    public init(groups: [BlockerGroup: GroupSettings] = BlockerGroup.allCases
                    .reduce(into: [:]) { $0[$1] = GroupSettings() },
                customRules: [CustomRule] = [],
                useICloudSync: Bool = true,
                useAppLock: Bool = false,
                lastFilterUpdate: Date? = nil,
                onboardingCompleted: Bool = false) {
        self.groups = groups
        self.customRules = customRules
        self.useICloudSync = useICloudSync
        self.useAppLock = useAppLock
        self.lastFilterUpdate = lastFilterUpdate
        self.onboardingCompleted = onboardingCompleted
    }
}
