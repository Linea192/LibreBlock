import Foundation

/// Compiles Adblock Plus syntax filter rules into Safari's WebKit content
/// blocker JSON format.
///
/// Supported ABP constructs:
///   - `||example.com^` domain anchor rules (incl. subdomain matching)
///   - `|https://...` and trailing `|` address anchors
///   - `*` wildcards, `^` separator placeholders
///   - `$script,image,stylesheet,xmlhttprequest,subdocument,font,media,third-party,domain=a|~b`
///   - `@@...` exception rules -> `ignore-previous-rules`
///   - `example.com##.ad` / `example.com#@#.ad` cosmetic rules
///   - `!` comments, `[Adblock Plus 2.0]` headers
///
/// Anything Safari cannot express is skipped safely rather than
/// approximated: regex filters (`/…/`), procedural selectors (`#?#`),
/// snippet filters (`#%#`, `##+js(`), `$csp`, `$document`, negated
/// resource types and unknown options.
public struct RuleCompiler {
    /// WebKit rejects content blockers above 150,000 rules; stay well under.
    public let maxRules: Int

    public init(maxRules: Int = 120_000) {
        self.maxRules = maxRules
    }

    // MARK: - Public API

    /// Compiles ABP list text into content blocker JSON.
    /// - Returns: JSON data and the number of compiled rules.
    public func compile(listText: String) throws -> (data: Data, count: Int) {
        var rules = compileToDictionaries(listText: listText)
        if rules.count > maxRules {
            rules = Array(rules.prefix(maxRules))
        }
        let data = try JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        return (data, rules.count)
    }

    /// Parses and compiles the list into rule dictionaries:
    /// network blocks first, then cosmetic rules, then exceptions last so
    /// `ignore-previous-rules` can cancel everything before it.
    func compileToDictionaries(listText: String) -> [[String: Any]] {
        var network: [[String: Any]] = []
        var exceptions: [[String: Any]] = []
        var cosmetic: [[String: Any]] = []

        for rawLine in listText.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("!"), !line.hasPrefix("[") else { continue }

            switch parseCosmetic(line) {
            case .skip:
                continue
            case .cosmetic(let domains, let selector, let isException):
                if let rule = cosmeticRule(domains: domains, selector: selector, isException: isException) {
                    (isException ? exceptions : cosmetic).append(rule)
                }
            case .notCosmetic:
                if let rule = networkRule(line) {
                    let isBlock = (rule["action"] as? [String: Any])?["type"] as? String == "block"
                    (isBlock ? network : exceptions).append(rule)
                }
            }
        }

        return network + cosmetic + exceptions
    }

    // MARK: - Cosmetic rules

    private enum CosmeticParse {
        case notCosmetic
        case skip
        case cosmetic(domains: [String], selector: String, isException: Bool)
    }

    private func parseCosmetic(_ line: String) -> CosmeticParse {
        // Procedural (#?#) and snippet (#%#, ##+js) filters cannot run in Safari.
        if line.contains("#?#") || line.contains("#%#") || line.contains("##+js(") {
            return .skip
        }

        let markers: [(String, Bool)] = [("##", false), ("#@#", true)]
        var best: (domains: [String], selector: String, isException: Bool)?
        var bestOffset = Int.max

        for (marker, isException) in markers {
            if let range = line.range(of: marker) {
                let offset = line.distance(from: line.startIndex, to: range.lowerBound)
                if offset < bestOffset {
                    let domainsPart = String(line[line.startIndex..<range.lowerBound])
                    let selector = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    best = (splitDomains(domainsPart), selector, isException)
                    bestOffset = offset
                }
            }
        }

        guard let (domains, selector, isException) = best, !selector.isEmpty else { return .notCosmetic }
        return .cosmetic(domains: domains, selector: selector, isException: isException)
    }

    private func cosmeticRule(domains: [String], selector: String, isException: Bool) -> [String: Any]? {
        // Only CSS selectors WebKit can compile are forwarded.
        guard isSimpleCSS(selector) else { return nil }

        var trigger: [String: Any] = ["url-filter": ".*"]
        let (included, excluded) = partitionDomains(domains)
        if !included.isEmpty { trigger["if-domain"] = included }
        if !excluded.isEmpty { trigger["unless-domain"] = excluded }

        let action: [String: Any] = isException
            ? ["type": "ignore-previous-rules"]
            : ["type": "css-display-none", "selector": selector]
        return ["trigger": trigger, "action": action]
    }

    /// Standard CSS selectors (attribute selectors, `:not()`, `:has()`,
    /// combinators) are fine. Reject pseudo-elements, ABP extended
    /// selectors and script snippets, which WebKit cannot compile.
    private func isSimpleCSS(_ selector: String) -> Bool {
        let forbidden = ["::", ":-abp-", "{", "}", "+js("]
        return !forbidden.contains { selector.contains($0) }
    }

    // MARK: - Network rules

    func networkRule(_ line: String) -> [String: Any]? {
        var isException = false
        var body = line
        if body.hasPrefix("@@") {
            isException = true
            body.removeFirst(2)
        }

        var options: [String] = []
        if let dollar = body.lastIndex(of: "$") {
            let optString = String(body[body.index(after: dollar)...])
            // Options are comma-separated tokens without whitespace.
            if !optString.isEmpty, !optString.contains(where: \.isWhitespace) {
                options = optString.split(separator: ",").map(String.init)
                body = String(body[body.startIndex..<dollar])
            }
        }
        guard !body.isEmpty, body.count <= 300 else { return nil }

        // ABP regex filters are written /like-this/; Safari's url-filter is
        // itself a regex, but translating ABP regexes faithfully is not
        // possible in general, so skip them.
        if body.hasPrefix("/"), body.hasSuffix("/"), body.count > 2 {
            return nil
        }

        var trigger: [String: Any] = [:]
        guard let urlFilter = urlFilter(fromPattern: body) else { return nil }
        trigger["url-filter"] = urlFilter

        var resourceTypes: Set<String> = []
        var loadType: [String]?
        var includedDomains: [String] = []
        var excludedDomains: [String] = []

        for rawOption in options {
            let option = rawOption.lowercased()
            let negated = option.hasPrefix("~")
            let token = negated ? String(option.dropFirst()) : option

            switch token {
            case "script":
                guard !negated else { return nil }
                resourceTypes.insert("script")
            case "image":
                guard !negated else { return nil }
                resourceTypes.insert("image")
            case "stylesheet":
                guard !negated else { return nil }
                resourceTypes.insert("style-sheet")
            case "xmlhttprequest":
                guard !negated else { return nil }
                resourceTypes.insert("rawfile")
            case "subdocument":
                guard !negated else { return nil }
                resourceTypes.insert("document")
            case "font":
                guard !negated else { return nil }
                resourceTypes.insert("font")
            case "media":
                guard !negated else { return nil }
                resourceTypes.insert("media")
            case "third-party":
                loadType = [negated ? "first-party" : "third-party"]
            case "domain":
                guard let eq = rawOption.firstIndex(of: "=") else { return nil }
                let (inc, exc) = partitionDomains(
                    rawOption[rawOption.index(after: eq)...]
                        .split(separator: "|").map(String.init))
                includedDomains += inc
                excludedDomains += exc
            case "match-case", "elemhide", "generichide", "genericblock", "popup":
                break // no Safari equivalent; harmless to drop the flag
            default:
                return nil // unknown option: skip the whole rule
            }
        }

        if !resourceTypes.isEmpty { trigger["resource-type"] = resourceTypes.sorted() }
        if let loadType { trigger["load-type"] = loadType }
        if !includedDomains.isEmpty { trigger["if-domain"] = includedDomains.sorted() }
        if !excludedDomains.isEmpty { trigger["unless-domain"] = excludedDomains.sorted() }

        let action: [String: Any] = isException
            ? ["type": "ignore-previous-rules"]
            : ["type": "block"]
        return ["trigger": trigger, "action": action]
    }

    // MARK: - Pattern translation

    /// Translates an ABP URL pattern into an ICU regex for `url-filter`.
    ///
    ///   `||example.com^` -> `^[a-z][a-z0-9+.-]*://(?:[^/]+\.)?example\.com(?:[^a-zA-Z0-9_.%-]|$)`
    ///   `|https://ads.`  -> `^https://ads\.`
    ///   `banner_*`       -> `banner_.*`
    func urlFilter(fromPattern pattern: String) -> String? {
        var p = Substring(pattern)

        var out = ""
        if p.hasPrefix("||") {
            // Domain anchor: any scheme, and subdomains of the literal host.
            out = "^[a-z][a-z0-9+.-]*://(?:[^/]+\\.)?"
            p = p.dropFirst(2)
        } else if p.hasPrefix("|") {
            out = "^"
            p = p.dropFirst()
        }
        var suffix = ""
        if p.hasSuffix("|") {
            suffix = "$"
            p = p.dropLast()
        }
        guard !p.isEmpty else { return nil }

        for ch in p {
            switch ch {
            case "*":
                out += ".*"
            case "^":
                // ABP separator: end of string or a non-domain character.
                out += "(?:[^a-zA-Z0-9_.%-]|$)"
            default:
                if "\\+?.()[]{}|$".contains(ch) {
                    out += "\\\(ch)"
                } else {
                    out.append(ch)
                }
            }
        }
        return out + suffix
    }

    // MARK: - Domains

    private func splitDomains(_ part: String) -> [String] {
        part.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Splits `domain=` / cosmetic domain lists into (included, excluded)
    /// with WebKit's leading `*` wildcard form.
    private func partitionDomains(_ raw: [String]) -> (included: [String], excluded: [String]) {
        var included: [String] = []
        var excluded: [String] = []
        for domain in raw {
            var d = domain.lowercased()
            var negative = false
            if d.hasPrefix("~") {
                negative = true
                d = String(d.dropFirst())
            }
            guard !d.isEmpty, d.allSatisfy({ $0.isLetter || $0.isNumber || ".-_*".contains($0) })
            else { continue }
            let wildcarded = "*\(d)"
            if negative { excluded.append(wildcarded) } else { included.append(wildcarded) }
        }
        return (included, excluded)
    }
}
