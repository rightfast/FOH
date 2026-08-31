import XCTest
@testable import FOH

final class BrowserDomainPolicyTests: XCTestCase {
    func testNormalizesURLsAndWWWHosts() {
        XCTAssertEqual(BrowserDomainPolicy.normalizedDomain("https://www.Meet.Google.com/call"), "meet.google.com")
        XCTAssertEqual(BrowserDomainPolicy.normalizedDomain(" zoom.us "), "zoom.us")
    }

    func testMatchesExactHostAndSubdomainsWithoutMatchingLookalikes() {
        let domains = ["zoom.us"]
        XCTAssertEqual(BrowserDomainPolicy.matchingDomain(for: URL(string: "https://zoom.us/wc/123")!, domains: domains), "zoom.us")
        XCTAssertEqual(BrowserDomainPolicy.matchingDomain(for: URL(string: "https://acme.zoom.us/j/123")!, domains: domains), "zoom.us")
        XCTAssertNil(BrowserDomainPolicy.matchingDomain(for: URL(string: "https://zoom.us.example.com")!, domains: domains))
    }

    func testRejectsInvalidDomain() {
        XCTAssertNil(BrowserDomainPolicy.normalizedDomain("localhost"))
        XCTAssertNil(BrowserDomainPolicy.normalizedDomain("   "))
    }
}
