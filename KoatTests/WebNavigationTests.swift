import HotwireNative
import SafariServices
import XCTest
import WebKit
@testable import Koat

@MainActor
final class WebNavigationTests: XCTestCase {
    private var server: WebFixtureServer!
    private var controller: AppWebViewController!
    private var sessionChanges = 0
    private var window: UIWindow!
    private var webView: WKWebView { controller.webView }

    override func setUp() async throws {
        server = try WebFixtureServer()
        try await server.start()
        sessionChanges = 0
        controller = AppWebViewController(rootURL: server.rootURL, dataStore: .nonPersistent(), sessionDidChange: { [weak self] in self?.sessionChanges += 1 })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.navigate(to: server.rootURL)
        try await waitFor("document.body?.dataset.page === 'home' && !!window.Turbo && nativeBridge.supportedComponents.length === 2")
    }

    override func tearDown() async throws {
        controller.dismiss(animated: false)
        webView.stopLoading()
        window.isHidden = true
        window.rootViewController = nil
        controller = nil
        window = nil
        server.stop()
        server = nil
    }

    func testFirstVisitKeepsPageAndNavbarVisibleThenUsesBrowserHistory() async throws {
        let originalWebView = webView
        try await run("window.originalDocument = document; document.querySelector('#exercises').click()")
        try await waitUntil { self.server.hasHeldResponse }
        try await waitFor("!!document.querySelector('.turbo-progress-bar')")
        try await assertJS("document.body.dataset.page === 'home'")
        try await assertJS("document.querySelector('#navbar').getBoundingClientRect().height > 0")
        // The launch cover from setUp may still be dissolving; only the web view and progress bar remain.
        try await waitUntil { self.controller.view.subviews.allSatisfy { $0 is WKWebView || $0 is UIProgressView } }
        server.releaseExercises()
        try await waitFor("document.body.dataset.page === 'exercises'")
        try await assertJS("window.originalDocument === document")
        XCTAssertTrue(webView === originalWebView)
        XCTAssertTrue(webView.allowsBackForwardNavigationGestures)
        XCTAssertTrue(webView.canGoBack)
        webView.goBack()
        try await waitFor("document.body.dataset.page === 'home'")
        webView.goForward()
        try await waitFor("document.body.dataset.page === 'exercises'")
        try await assertJS("nativeBridge.supportedComponents.includes('apple-sign-in') && nativeBridge.supportedComponents.includes('google-sign-in')")
        XCTAssertNil(controller.navigationController)
    }

    func testLaunchLogoStaysUntilFirstPageLoadsAndNeverReturns() async throws {
        controller = AppWebViewController(rootURL: server.rootURL, dataStore: .nonPersistent())
        window.rootViewController = controller
        controller.navigate(to: server.rootURL.appendingPathComponent("exercises"))
        try await waitUntil { self.server.hasHeldResponse }
        let cover = try XCTUnwrap(controller.view.subviews.first { $0.accessibilityIdentifier == "launchCover" })
        XCTAssertFalse(cover.isHidden)
        XCTAssertTrue(cover.subviews.contains { ($0 as? UIImageView)?.image != nil })
        server.releaseExercises()
        try await waitFor("document.body.dataset.page === 'exercises'")
        try await waitUntil { cover.superview == nil }
        controller.navigate(to: server.rootURL.appendingPathComponent("settings"), replacingDocument: true)
        try await waitFor("document.body.dataset.page === 'settings'")
        XCTAssertFalse(controller.view.subviews.contains { $0.accessibilityIdentifier == "launchCover" })
    }

    func testLaunchCoverContinuesSystemLaunchArtworkWithoutASeam() throws {
        let bounds = CGRect(x: 0, y: 0, width: 393, height: 852)
        let launch = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: Bundle(for: AppWebViewController.self)).instantiateInitialViewController())
        launch.view.frame = bounds
        launch.view.layoutIfNeeded()
        let systemMark = try XCTUnwrap(launch.view.subviews.compactMap { $0 as? UIImageView }.first { $0.image != nil })

        let cold = AppWebViewController(rootURL: server.rootURL, dataStore: .nonPersistent())
        cold.view.frame = bounds
        cold.view.layoutIfNeeded()
        let cover = try XCTUnwrap(cold.view.subviews.first { $0.accessibilityIdentifier == "launchCover" })
        let coverMark = try XCTUnwrap(cover.subviews.compactMap { $0 as? UIImageView }.first { $0.image != nil })

        XCTAssertEqual(rgba(launch.view.backgroundColor), rgba(cover.backgroundColor))
        XCTAssertEqual(systemMark.image?.size, coverMark.image?.size)
        XCTAssertEqual(systemMark.contentMode, coverMark.contentMode)
        XCTAssertEqual(systemMark.frame.origin.x, coverMark.frame.origin.x, accuracy: 0.5)
        XCTAssertEqual(systemMark.frame.origin.y, coverMark.frame.origin.y, accuracy: 0.5)
        XCTAssertEqual(systemMark.frame.size, coverMark.frame.size)
        XCTAssertEqual(coverMark.frame.size, CGSize(width: LaunchArtwork.markSize, height: LaunchArtwork.markSize))
        XCTAssertEqual(coverMark.center.y, bounds.midY * LaunchArtwork.markCenterYMultiplier, accuracy: 0.5)
        XCTAssertTrue(cover.accessibilityViewIsModal)
    }

    func testNativeDeepLinkUsesTurboAndQuotesURLSafely() async throws {
        try await run("window.originalDocument = document")
        controller.navigate(to: URL(string: "settings?q=%27%22%2B%26", relativeTo: server.rootURL)!.absoluteURL)
        try await waitFor("document.body.dataset.page === 'settings'")
        try await assertJS("window.originalDocument === document")
        let query = try await webView.evaluateJavaScript("new URL(location.href).searchParams.get('q')") as? String
        XCTAssertEqual(query, "'\"+&")
    }

    func testNotificationOpensAppStoreOutsideRunningApp() async throws {
        var opened: [URL] = []
        let app = App(rootURL: server.rootURL, openExternalURL: { opened.append($0) })
        controller = app.webViewController
        window.rootViewController = app.rootViewController
        app.start()
        try await waitFor("document.body?.dataset.page === 'home'")
        let storeURL = URL(string: "https://apps.apple.com/br/app/koat/id6748588637")!

        app.handleDeepLink(path: storeURL.absoluteString)

        XCTAssertEqual(opened, [storeURL])
        XCTAssertEqual(webView.url, server.rootURL)
    }

    func testNotificationOpensAppStoreOnceAfterColdStart() async throws {
        var opened: [URL] = []
        let app = App(rootURL: server.rootURL, openExternalURL: { opened.append($0) })
        let storeURL = URL(string: "https://apps.apple.com/br/app/koat/id6748588637")!
        app.handleDeepLink(path: storeURL.absoluteString)
        XCTAssertTrue(opened.isEmpty)

        controller = app.webViewController
        window.rootViewController = app.rootViewController
        app.start()
        app.start()

        XCTAssertEqual(opened, [storeURL])
        try await waitFor("document.body?.dataset.page === 'home'")
        XCTAssertEqual(webView.url, server.rootURL)
    }

    func testNotificationKeepsInternalLinksInAppAndRejectsUnsafeURLs() async throws {
        var opened: [URL] = []
        let app = App(rootURL: server.rootURL, openExternalURL: { opened.append($0) })
        app.handleDeepLink(path: "/settings?ref=push")
        controller = app.webViewController
        window.rootViewController = app.rootViewController
        app.start()
        try await waitFor("document.body?.dataset.page === 'settings'")
        XCTAssertEqual(webView.url?.query, "ref=push")

        app.handleDeepLink(path: server.rootURL.absoluteString)
        try await waitFor("document.body?.dataset.page === 'home'")
        for path in ["javascript:alert(1)", "file:///tmp/test", "https://user:password@example.com", "https://"] {
            app.handleDeepLink(path: path)
        }
        XCTAssertTrue(opened.isEmpty)
        XCTAssertEqual(webView.url, server.rootURL)
    }

    func testSessionRedemptionReplacesDocumentAndKeepsCookie() async throws {
        try await run("window.oldSessionMarker = true")
        controller.navigate(to: server.rootURL.appendingPathComponent("session"), replacingDocument: true)
        try await waitFor("document.body.dataset.page === 'signed-in' && !!window.Turbo")
        try await assertJS("typeof window.oldSessionMarker === 'undefined'")
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        XCTAssertEqual(cookies.first { $0.name == "session_id" }?.value, "test-session")
        try await waitUntil { self.sessionChanges == 1 }
        XCTAssertFalse(webView.backForwardList.backList.contains { $0.url.path == "/session" })
        try await waitFor("nativeBridge.supportedComponents.length === 2")
    }

    func testNewWindowLinkStaysInSameWebView() async throws {
        let originalWebView = webView
        try await run("document.querySelector('#popup').click()")
        try await waitFor("document.body.dataset.page === 'popup'")
        XCTAssertTrue(webView === originalWebView)
    }

    func testBridgeMessagesAndRepliesSurviveWebNavigation() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("settings"))
        try await waitFor("document.body.dataset.page === 'settings'")
        // Exercise the actual transport and components without invoking an OAuth UI.
        try await run("""
            window.HotwireNative = { web: { receive: message => window.bridgeReply = message } };
            nativeBridge.receive({ id: 'apple-probe', component: 'apple-sign-in', event: 'probe', data: {metadata: {url: location.href}} });
            nativeBridge.receive({ id: 'google-probe', component: 'google-sign-in', event: 'probe', data: {metadata: {url: location.href}} })
            """)
        try await waitUntil {
            let apple: AppleSignInComponent? = self.controller.bridgeDelegate.component()
            let google: GoogleSignInComponent? = self.controller.bridgeDelegate.component()
            return apple?.receivedMessage(for: "probe") != nil && google?.receivedMessage(for: "probe") != nil
        }
        let apple: AppleSignInComponent = try XCTUnwrap(controller.bridgeDelegate.component())
        let appleReplied = try await apple.reply(to: "probe")
        XCTAssertTrue(appleReplied)
        try await waitFor("window.bridgeReply?.id === 'apple-probe'")
        let google: GoogleSignInComponent = try XCTUnwrap(controller.bridgeDelegate.component())
        let googleReplied = try await google.reply(to: "probe")
        XCTAssertTrue(googleReplied)
        try await waitFor("window.bridgeReply?.id === 'google-probe'")
    }

    func testPDFMessageOpensNativeShareSheet() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("session"), replacingDocument: true)
        try await waitFor("document.body.dataset.page === 'signed-in'")
        try await run("webkit.messageHandlers.pdfExport.postMessage({url: '/pdf'})")
        try await waitUntil { self.controller.presentedViewController is UIActivityViewController }
        XCTAssertTrue(server.pdfReceivedSessionCookie)
    }

    func testDeepLinkDuringDocumentLoadIsDeliveredAfterLoad() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("exercises"), replacingDocument: true)
        try await waitUntil { self.server.hasHeldResponse }
        controller.navigate(to: server.rootURL.appendingPathComponent("settings"))
        server.releaseExercises()
        try await waitFor("document.body.dataset.page === 'settings'")
    }

    func testNativeEntryPointFallsBackOnPagesWithoutTurbo() async throws {
        webView.load(URLRequest(url: server.rootURL.appendingPathComponent("plain")))
        try await waitFor("document.body.dataset.page === 'plain' && document.readyState === 'complete'")
        controller.navigate(to: server.rootURL.appendingPathComponent("settings"))
        try await waitFor("document.body.dataset.page === 'settings'")
    }

    func testProcessRecoveryReloadsCurrentPageAndRestoresBridge() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("settings"))
        try await waitFor("document.body.dataset.page === 'settings'")
        try await run("window.beforeRecovery = true")
        controller.webViewWebContentProcessDidTerminate(webView)
        controller.recoverIfNeeded()
        try await waitFor("document.body.dataset.page === 'settings' && typeof window.beforeRecovery === 'undefined' && nativeBridge.supportedComponents.length === 2")
    }

    func testNavigationPolicyRejectsForeignOriginsAndUnsafeSchemes() {
        let policy = WebNavigationPolicy(rootURL: URL(string: "https://app.koat.io")!)
        for url in ["https://app.koat.io/exercises", "https://app.koat.io:443/settings"] {
            XCTAssertTrue(policy.isInternal(URL(string: url)!), url)
        }
        for url in ["https://app.koat.io.evil.test", "https://other.koat.io", "http://app.koat.io", "https://app.koat.io:444", "https://user@app.koat.io", "javascript:alert(1)", "file:///tmp/test", "mailto:a@b.test"] {
            XCTAssertFalse(policy.isInternal(URL(string: url)!), url)
        }
    }

    func testExternalRedirectOpensBrowserWithoutReplacingAppPage() async throws {
        try await run("location.assign('/escape')")
        try await waitUntil { self.controller.presentedViewController is SFSafariViewController }
        XCTAssertEqual(webView.url?.host, server.rootURL.host)
        try await assertJS("document.body.dataset.page === 'home'")
    }

    func testCheckoutCapabilityIsAdvertisedAlongsideBridgeComponents() async throws {
        try await assertJS("navigator.userAgent.includes('Koat iOS') && navigator.userAgent.includes('KoatCheckoutReturn/1;')")
        try await assertJS("nativeBridge.supportedComponents.length === 2")
    }

    func testCheckoutCallbackClosesSafariAndKeepsAuthenticatedCookie() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("session"), replacingDocument: true)
        try await waitFor("document.body.dataset.page === 'signed-in'")
        try await run("location.assign('/escape')")
        try await waitUntil { self.controller.presentedViewController is SFSafariViewController }
        let originalWebView = webView
        controller.returnFromCheckout(to: server.rootURL.appendingPathComponent("subscriptions/checkouts/123/return"))
        try await waitFor("document.body.dataset.page === 'checkout-return'")
        XCTAssertNil(controller.presentedViewController)
        XCTAssertTrue(webView === originalWebView)
        XCTAssertTrue(server.checkoutReceivedSessionCookie)
    }

    func testCheckoutCallbackSupersedesAnInFlightDocumentLoad() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("exercises"), replacingDocument: true)
        try await waitUntil { self.server.hasHeldResponse }
        controller.returnFromCheckout(to: server.rootURL.appendingPathComponent("subscriptions/checkouts/123/return"))
        try await waitFor("document.body.dataset.page === 'checkout-return'")
        server.releaseExercises()
        XCTAssertEqual(webView.url?.path, "/subscriptions/checkouts/123/return")
    }

    func testCustomCheckoutCallbackWorksBeforeAppStartAndWhileRunning() async throws {
        var opened: [URL] = []
        let app = App(rootURL: server.rootURL, openExternalURL: { opened.append($0) })
        XCTAssertTrue(app.handleCheckoutReturn(URL(string: "koat://checkout-return/123")!))
        controller = app.webViewController
        window.rootViewController = app.rootViewController
        app.start()
        try await waitFor("document.body?.dataset.page === 'checkout-return'")
        controller.navigate(to: server.rootURL)
        try await waitFor("document.body.dataset.page === 'home'")
        XCTAssertTrue(app.handleCheckoutReturn(URL(string: "koat://checkout-return/123")!))
        try await waitFor("document.body.dataset.page === 'checkout-return'")
        XCTAssertFalse(app.handleCheckoutReturn(URL(string: "https://evil.test/subscriptions/checkouts/123/return?app_return=ios")!))
        XCTAssertTrue(opened.isEmpty)
    }

    func testManuallyClosingStripeRechecksKnownCheckoutOnce() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("subscriptions/checkouts/123"))
        try await waitFor("document.body.dataset.page === 'checkout'")
        try await run("location.assign('https://checkout.stripe.com/c/pay/koat-test')")
        try await waitUntil { self.controller.presentedViewController is SFSafariViewController }
        let safari = try XCTUnwrap(controller.presentedViewController as? SFSafariViewController)
        controller.safariViewControllerDidFinish(safari)
        try await waitFor("document.body.dataset.page === 'checkout-return'")
        controller.safariViewControllerDidFinish(safari)
        XCTAssertEqual(server.requests.filter { $0 == "/subscriptions/checkouts/123/return" }.count, 1)
    }

    func testClosingInitialCheckoutReturnsToOnboardingWithoutReposting() async throws {
        controller.navigate(to: server.rootURL.appendingPathComponent("onboarding"))
        try await waitFor("document.body.dataset.page === 'onboarding'")
        try await run("document.querySelector('#checkout-form').submit()")
        try await waitUntil { self.controller.presentedViewController is SFSafariViewController }
        let safari = try XCTUnwrap(controller.presentedViewController as? SFSafariViewController)
        controller.safariViewControllerDidFinish(safari)
        try await waitUntil { self.server.requests.filter { $0 == "/onboarding" }.count == 2 }
        try await waitFor("document.body.dataset.page === 'onboarding'")
        XCTAssertEqual(server.requests.filter { $0 == "/subscriptions/checkouts" }.count, 1)
    }

    func testClosingUnrelatedSafariDoesNotStartCheckoutRecovery() async throws {
        try await run("location.assign('/escape')")
        try await waitUntil { self.controller.presentedViewController is SFSafariViewController }
        let safari = try XCTUnwrap(controller.presentedViewController as? SFSafariViewController)
        controller.safariViewControllerDidFinish(safari)
        try await assertJS("document.body.dataset.page === 'home'")
        XCTAssertFalse(server.requests.contains { $0.hasPrefix("/subscriptions") })
    }

    func testFailedDocumentLoadOffersRetry() async throws {
        try await run("location.assign('/offline')")
        try await waitUntil { self.controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Não foi possível carregar a página")
        XCTAssertTrue(alert.actions.contains { $0.title == "Tentar novamente" })
    }

    private func run(_ script: String) async throws {
        _ = try await webView.evaluateJavaScript(script + "; true")
    }

    private func assertJS(_ script: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let result = try await webView.evaluateJavaScript(script) as? Bool
        XCTAssertEqual(result, true, script, file: file, line: line)
    }

    private func rgba(_ color: UIColor?) -> [CGFloat]? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color?.getRed(&r, green: &g, blue: &b, alpha: &a) == true else { return nil }
        return [r, g, b, a].map { ($0 * 1000).rounded() / 1000 }
    }

    private func waitFor(_ script: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await waitUntil(file: file, line: line) { (try? await self.webView.evaluateJavaScript(script)) as? Bool == true }
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line, _ condition: () async throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Timed out waiting for browser state", file: file, line: line)
        throw NSError(domain: "WebNavigationTests", code: 1)
    }
}
