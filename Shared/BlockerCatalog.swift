import Foundation

/// The built-in catalog of filter subscriptions.
///
/// Default-on lists ship compiled inside the app so blocking works on first
/// launch without a network round-trip. Remote lists are fetched on refresh
/// and cached in the App Group container. All remote lists are public,
/// freely redistributable filter subscriptions (EasyList family and others);
/// see ATTRIBUTION.md for licenses.
public enum BlockerCatalog {
    public struct Entry: Sendable {
        public let id: String
        public let name: String
        public let kind: FilterList.Kind
        public let url: URL?
        public let group: BlockerGroup
        public let implies: [String]
        public let chosenByDefault: Bool

        public init(id: String,
                    name: String,
                    kind: FilterList.Kind,
                    url: URL? = nil,
                    group: BlockerGroup,
                    implies: [String] = [],
                    chosenByDefault: Bool = false) {
            self.id = id
            self.name = name
            self.kind = kind
            self.url = url
            self.group = group
            self.implies = implies
            self.chosenByDefault = chosenByDefault
        }
    }

    public static let shared: [Entry] = [
        // -- Ads ----------------------------------------------------------
        Entry(id: "easylist", name: "EasyList", kind: .ads,
              url: URL(string: "https://easylist.to/easylist/easylist.txt"),
              group: .ads, chosenByDefault: true),
        Entry(id: "mobile-ads", name: "Mobile Ad Networks", kind: .ads,
              group: .ads, chosenByDefault: true),
        Entry(id: "popups", name: "Pop-ups & Interstitials", kind: .ads,
              group: .ads, chosenByDefault: true),

        // -- Privacy --------------------------------------------------------
        Entry(id: "easyprivacy", name: "EasyPrivacy", kind: .privacy,
              url: URL(string: "https://easylist.to/easylist/easyprivacy.txt"),
              group: .privacy, chosenByDefault: true),
        Entry(id: "mobile-trackers", name: "Mobile Trackers", kind: .privacy,
              group: .privacy, chosenByDefault: true),

        // -- Social ----------------------------------------------------------
        Entry(id: "social-widgets", name: "Social Widgets & Buttons", kind: .social,
              group: .social, chosenByDefault: true),
        Entry(id: "social-embeds", name: "Social Video Embeds", kind: .social,
              group: .social, chosenByDefault: false),

        // -- Safety ----------------------------------------------------------
        Entry(id: "phishing-army", name: "Phishing Army", kind: .safety,
              url: URL(string: "https://phishing.army/download/phishing_army_blocklist_extended.txt"),
              group: .safety, chosenByDefault: true),
        Entry(id: "adaway", name: "AdAway Hosts", kind: .safety,
              url: URL(string: "https://adaway.org/hosts.txt"),
              group: .safety, chosenByDefault: false),
        Entry(id: "nocoin", name: "NoCoin (Crypto Mining)", kind: .safety,
              url: URL(string: "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/nocoin.txt"),
              group: .safety, chosenByDefault: true),

        // -- Others ----------------------------------------------------------
        Entry(id: "fanboy-annoyance", name: "Fanboy's Annoyances", kind: .annoyances,
              url: URL(string: "https://secure.fanboy.co.nz/fanboy-annoyance.txt"),
              group: .others, chosenByDefault: false),
        Entry(id: "cookies", name: "Cookie Consent Banners", kind: .annoyances,
              group: .others, chosenByDefault: true),
        Entry(id: "anti-adblock", name: "Anti-Adblock Warning Removal", kind: .annoyances,
              url: URL(string: "https://easylist-downloads.adblockplus.org/antiadblockfilters.txt"),
              group: .others, chosenByDefault: false),
        Entry(id: "webfonts", name: "Local Web Fonts", kind: .annoyances,
              group: .others, chosenByDefault: false),

        // -- Regional (each implies EasyList) -------------------------------
        Entry(id: "easylist-germany", name: "EasyList Germany", kind: .regional,
              url: URL(string: "https://easylist.to/easylistgermany/easylistgermany.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "liste-fr", name: "Liste FR", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/liste_fr.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "easylist-china", name: "EasyList China", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/easylistchina.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "rolist", name: "ROList", kind: .regional,
              url: URL(string: "https://www.zoso.ro/pages/rolist.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "ru-adlist", name: "RU AdList", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/advblock.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "easylist-italy", name: "EasyList Italy", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/easylistitaly.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "easylist-spanish", name: "EasyList Spanish", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/easylistspanish.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "easylist-dutch", name: "EasyList Dutch", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/easylistdutch.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "easylist-portuguese", name: "EasyList Portuguese", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/easylistportuguese.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "korean-list", name: "KoreanList", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/koreanlist.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "indian-list", name: "IndianList", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/indianlist.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "easylist-hebrew", name: "EasyList Hebrew", kind: .regional,
              url: URL(string: "https://raw.githubusercontent.com/easylist/EasyListHebrew/master/EasyListHebrew.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "nordic-filters", name: "Dandelion Sprout's Nordic Filters", kind: .regional,
              url: URL(string: "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/NorwegianExperimentalList%20alternate%20versions/NordicFiltersABP-Inclusion.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "czech-slovak", name: "EasyList Czech and Slovak", kind: .regional,
              url: URL(string: "https://raw.githubusercontent.com/tomasko126/easylistczechandslovak/master/filters.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "abpindo", name: "ABPindo", kind: .regional,
              url: URL(string: "https://raw.githubusercontent.com/heradhis/indonesianadblockrules/master/subscriptions/abpindo.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "abpvn", name: "ABPVN List", kind: .regional,
              url: URL(string: "https://abpvn.com/filter/abpvn-IPl6HE.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "liste-ar", name: "Liste AR", kind: .regional,
              url: URL(string: "https://easylist-downloads.adblockplus.org/Liste_AR.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "latvian-list", name: "Latvian List", kind: .regional,
              url: URL(string: "https://raw.githubusercontent.com/Latvian-List/adblock-latvian/master/lists/latvian-list.txt"),
              group: .ads, implies: ["easylist"]),
        Entry(id: "lithuania", name: "EasyList Lithuania", kind: .regional,
              url: URL(string: "https://raw.githubusercontent.com/EasyList-Lithuania/easylist_lithuania/master/easylistlithuania.txt"),
              group: .ads, implies: ["easylist"]),
    ]

    /// Builds the user-facing list state (chosen flags) from the catalog and
    /// the persisted selection, adding any newly introduced entries.
    public static func lists(selection: [String: Bool] = [:]) -> [FilterList] {
        shared.map { entry in
            FilterList(id: entry.id,
                       name: entry.name,
                       kind: entry.kind,
                       url: entry.url,
                       group: entry.group,
                       implies: entry.implies,
                       chosen: selection[entry.id] ?? entry.chosenByDefault)
        }
    }
}
