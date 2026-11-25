import Foundation

/// Identifies one of the six Safari content blocker extensions.
/// Each maps to a bundled app extension and a set of filter lists.
public enum BlockerGroup: String, CaseIterable, Codable, Sendable, Identifiable {
    case ads
    case privacy
    case social
    case safety
    case others
    case custom

    public var id: String { rawValue }

    /// The file name used for this group's compiled rule JSON inside
    /// the shared App Group container.
    public var fileName: String { "blocker-\(rawValue).json" }

    /// The extension bundle display name shown in Safari's settings.
    public var extensionName: String {
        switch self {
        case .ads: return "1. Ads"
        case .privacy: return "2. Privacy"
        case .social: return "3. Social"
        case .safety: return "4. Safety"
        case .others: return "5. Others"
        case .custom: return "6. Custom"
        }
    }

    public var title: String {
        switch self {
        case .ads: return "Ads"
        case .privacy: return "Privacy"
        case .social: return "Social"
        case .safety: return "Safety"
        case .others: return "Others"
        case .custom: return "Custom"
        }
    }

    public var systemImage: String {
        switch self {
        case .ads: return "megaphone"
        case .privacy: return "eye.slash"
        case .social: return "person.2"
        case .safety: return "shield.lefthalf.filled"
        case .others: return "square.grid.2x2"
        case .custom: return "slider.horizontal.3"
        }
    }

    public var summary: String {
        switch self {
        case .ads: return "Banners, video ads, pop-ups and mobile ad networks."
        case .privacy: return "Trackers, analytics, fingerprinting and consent banners."
        case .social: return "Like/share widgets, embeds and social plugins."
        case .safety: return "Phishing, malware and crypto-mining domains."
        case .others: return "Annoyances, cookie banners and anti-adblock warnings."
        case .custom: return "Your own allow and block rules."
        }
    }
}
