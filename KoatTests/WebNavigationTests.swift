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
        XCTAssertTrue(controller.view.subviews.allSatisfy { $0 is WKWebView || $0 is UIProgressView })
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

    func testNativeDeepLinkUsesTurboAndQuotesURLSafely() async throws {
        try await run("window.originalDocument = document")
        controller.navigate(to: URL(string: "settings?q=%27%22%2B%26", relativeTo: server.rootURL)!.absoluteURL)
        try await waitFor("document.body.dataset.page === 'settings'")
        try await assertJS("window.originalDocument === document")
        let query = try await webView.evaluateJavaScript("new URL(location.href).searchParams.get('q')") as? String
        XCTAssertEqual(query, "'\"+&")
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
