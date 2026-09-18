import XCTest
@testable import Koat

@MainActor
final class CheckoutReturnLinkTests: XCTestCase {
    private let production = URL(string: "https://app.koat.io")!

    func testCustomSchemeMapsToConfiguredOriginForLocalQA() {
        let links = CheckoutReturnLink(rootURL: URL(string: "http://app.localhost:3000")!)
        XCTAssertEqual(links.destination(for: URL(string: "koat://checkout-return/123")!)?.absoluteString,
                       "http://app.localhost:3000/subscriptions/checkouts/123/return")
    }

    func testUniversalLinkDropsUntrustedQueryValues() {
        let links = CheckoutReturnLink(rootURL: production)
        let url = URL(string: "https://app.koat.io/subscriptions/checkouts/123/return?app_return=ios&return_url=https://evil.test&success=true")!
        XCTAssertEqual(links.destination(for: url)?.absoluteString,
                       "https://app.koat.io/subscriptions/checkouts/123/return")
    }

    func testRejectsMalformedForeignAndNonCheckoutLinks() {
        let links = CheckoutReturnLink(rootURL: production)
        for value in [
            "koat://checkout-return/nope", "koat://checkout-return/123/extra",
            "koat://checkout-return/123?url=https://evil.test", "koat://checkout-return/123#success",
            "koat://checkout-return:123/123", "koat://user@checkout-return/123",
            "koat://checkout-return/%31", "koat://checkout-return/123%2F..",
            "koat://other/123", "https://evil.test/subscriptions/checkouts/123/return?app_return=ios",
            "https://app.koat.io.evil.test/subscriptions/checkouts/123/return?app_return=ios",
            "https://user@app.koat.io/subscriptions/checkouts/123/return?app_return=ios",
            "https://app.koat.io:444/subscriptions/checkouts/123/return?app_return=ios",
            "http://app.koat.io/subscriptions/checkouts/123/return?app_return=ios",
            "https://app.koat.io/subscriptions/checkouts/123/return",
            "https://app.koat.io/subscriptions/checkouts/123/return?app_return=android",
            "https://app.koat.io/subscriptions/checkouts/123/return?app_return=ios&app_return=android",
            "https://app.koat.io/subscriptions/checkouts/123/return?app_return=ios&browser=1",
            "https://app.koat.io/settings?app_return=ios"
        ] {
            XCTAssertNil(links.destination(for: URL(string: value)!), value)
        }
    }

    func testManualRecoveryUsesCheckoutOrRailsRecoveryFlow() {
        let links = CheckoutReturnLink(rootURL: production)
        XCTAssertEqual(links.recoveryURL(from: URL(string: "https://app.koat.io/subscriptions/checkouts/123")!).path,
                       "/subscriptions/checkouts/123/return")
        XCTAssertEqual(links.recoveryURL(from: URL(string: "https://app.koat.io/onboarding/payment?plan_id=1")!).path,
                       "/onboarding")
        XCTAssertEqual(links.recoveryURL(from: nil).path, "/subscriptions")
        XCTAssertEqual(links.recoveryURL(from: URL(string: "https://evil.test/subscriptions/checkouts/123")!).path,
                       "/subscriptions")
    }
}
