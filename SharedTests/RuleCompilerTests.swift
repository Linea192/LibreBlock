import XCTest
@testable import LibreBlock

final class RuleCompilerTests: XCTestCase {
    private let compiler = RuleCompiler()

    // MARK: - Happy paths

    func testDomainAnchorRule() throws {
        let rules = try compile("||doubleclick.net^")
        XCTAssertEqual(rules.count, 1)
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["url-filter"] as? String,
                       "^[a-z][a-z0-9+.-]*://(?:[^/]+\\.)?doubleclick\\.net(?:[^a-zA-Z0-9_.%-]|$)")
        let action = try XCTUnwrap(rules.first?["action"] as? [String: Any])
        XCTAssertEqual(action["type"] as? String, "block")
    }

    func testExceptionRule() throws {
        let rules = try compile("@@||example.com^")
        let action = try XCTUnwrap(rules.first?["action"] as? [String: Any])
        XCTAssertEqual(action["type"] as? String, "ignore-previous-rules")
    }

    func testResourceTypes() throws {
        let rules = try compile("||ads.example.com^$script,image")
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["resource-type"] as? [String], ["image", "script"])
    }

    func testThirdParty() throws {
        let rules = try compile("||tracker.io^$third-party")
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["load-type"] as? [String], ["third-party"])
    }

    func testDomainOption() throws {
        let rules = try compile("||ads.net^$domain=foo.com|~bar.org")
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["if-domain"] as? [String], ["*foo.com"])
        XCTAssertEqual(trigger["unless-domain"] as? [String], ["*bar.org"])
    }

    func testWildcardPattern() throws {
        let rules = try compile("banner_*x")
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["url-filter"] as? String, "banner_.*x")
    }

    func testCosmeticRule() throws {
        let rules = try compile("example.com##.ad-banner")
        let action = try XCTUnwrap(rules.first?["action"] as? [String: Any])
        XCTAssertEqual(action["type"] as? String, "css-display-none")
        XCTAssertEqual(action["selector"] as? String, ".ad-banner")
        let trigger = try XCTUnwrap(rules.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["if-domain"] as? [String], ["*example.com"])
    }

    func testCosmeticException() throws {
        let rules = try compile("example.com#@#.promo")
        let action = try XCTUnwrap(rules.first?["action"] as? [String: Any])
        XCTAssertEqual(action["type"] as? String, "ignore-previous-rules")
    }

    func testCommentsAndHeadersSkipped() throws {
        let rules = try compile("""
        ! comment line
        [Adblock Plus 2.0]

        ||ads.example^
        """)
        XCTAssertEqual(rules.count, 1)
    }

    func testExceptionsOrderedAfterBlocks() throws {
        let rules = try compile("""
        ||ads.example^
        @@||ads.example.com/track^
        """)
        XCTAssertEqual(rules.count, 2)
        let last = try XCTUnwrap(rules.last?["action"] as? [String: Any])
        XCTAssertEqual(last["type"] as? String, "ignore-previous-rules")
    }

    // MARK: - Skipped constructs

    func testSnippetRuleSkipped() throws {
        XCTAssertEqual(try compile("example.com##+js(set-constant, ads, false)").count, 0)
    }

    func testRegexRuleSkipped() throws {
        XCTAssertEqual(try compile("/ad[0-9]+/$script").count, 0)
    }

    func testUnknownOptionSkipped() throws {
        XCTAssertEqual(try compile("||example.com^$weird").count, 0)
    }

    func testNegatedResourceTypeSkipped() throws {
        XCTAssertEqual(try compile("||example.com^$~image").count, 0)
    }

    func testPopupOptionDroppedButRuleKept() throws {
        // $popup has no Safari equivalent; the flag is dropped, rule stays.
        let rules = try compile("||pop.example^$popup")
        XCTAssertEqual(rules.count, 1)
    }

    // MARK: - Caps and output

    func testMaxRulesCap() throws {
        let text = (0..<300).map { "||host\($0).example^" }.joined(separator: "\n")
        let capped = RuleCompiler(maxRules: 150)
        let (data, count) = try capped.compile(listText: text)
        XCTAssertEqual(count, 150)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(decoded?.count, 150)
    }

    func testOutputIsValidJSON() throws {
        let (data, _) = try compiler.compile(listText: "||ads.example^\nexample.com##.ad")
        let decoded = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(decoded is [[String: Any]])
    }

    func testEmptyInputProducesEmptyArray() throws {
        let (data, count) = try compiler.compile(listText: "")
        XCTAssertEqual(count, 0)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? [[String: Any]], [])
    }

    // MARK: - Helpers

    private func compile(_ text: String, maxRules: Int = 120_000) throws -> [[String: Any]] {
        let (data, _) = try compiler.compile(listText: text)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return decoded ?? []
    }
}

final class CustomRuleCompilationTests: XCTestCase {
    func testAllowRuleWithDomains() throws {
        let compiler = RuleCompiler()
        // Same shape FilterEngine.rebuildCustom produces.
        let text = "@@*/ads/*$domain=news.example|shop.test"
        let (data, count) = try compiler.compile(listText: text)
        XCTAssertEqual(count, 1)
        let rules = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let trigger = try XCTUnwrap(rules?.first?["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["if-domain"] as? [String], ["*news.example", "*shop.test"])
    }
}
