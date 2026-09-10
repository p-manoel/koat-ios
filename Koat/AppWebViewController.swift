import HotwireNative
import SafariServices
import UIKit
import WebKit

/// Rails and browser Turbo own page navigation. Hotwire supplies only the bridge;
/// no Session/Navigator or native Turbo adapter is installed.
final class AppWebViewController: UIViewController, BridgeDestination {
    static let bridgeComponents: [BridgeComponent.Type] = [GoogleSignInComponent.self, AppleSignInComponent.self]

    let rootURL: URL
    private let dataStore: WKWebsiteDataStore
    private let sessionDidChange: () -> Void
    private var policy: WebNavigationPolicy { WebNavigationPolicy(rootURL: rootURL) }
    private(set) var webView: WKWebView!
    private(set) var bridgeDelegate: BridgeDelegate!
    private var pdfExportHandler: PDFExportHandler!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private var launchCover: UIView?
    private var progressObservation: NSKeyValueObservation?
    private var pendingNavigation: (url: URL, replacingDocument: Bool)?
    private var documentReady = false
    private var needsRecovery = false
    private var retryURL: URL?
    private var lastSessionCookie: String?

    init(rootURL: URL, dataStore: WKWebsiteDataStore = .default(), sessionDidChange: @escaping () -> Void = { PushNotificationManager.shared.refreshTokenRegistration() }) {
        self.rootURL = rootURL
        self.dataStore = dataStore
        self.sessionDidChange = sessionDidChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        dataStore.httpCookieStore.remove(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let configuration = WKWebViewConfiguration()
        let names = Self.bridgeComponents.map { $0.name }.joined(separator: " ")
        // Rails receives the full mobile web interface, plus native sign-in buttons.
        configuration.applicationNameForUserAgent = "Koat iOS; bridge-components: [\(names)]"
        configuration.websiteDataStore = dataStore
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.preferences.isFraudulentWebsiteWarningEnabled = false
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.userContentController.addUserScript(WKUserScript(source: """
            document.addEventListener('turbo:load', () => {
                webkit.messageHandlers.pageLoaded.postMessage({});
            });
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        #if DEBUG
        webView.isInspectable = true
        #endif
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        Bridge.initialize(webView)
        bridgeDelegate = BridgeDelegate(location: rootURL.absoluteString, destination: self, componentTypes: Self.bridgeComponents)
        bridgeDelegate.webViewDidBecomeActive(webView)
        bridgeDelegate.onViewDidLoad()
        pdfExportHandler = PDFExportHandler(presentingViewController: self, dataStore: dataStore)
        configuration.userContentController.add(WeakScriptMessageHandler(self), name: "pdfExport")
        configuration.userContentController.add(WeakScriptMessageHandler(self), name: "pageLoaded")

        // Continue the system launch artwork until the first document is ready.
        // Same composition as LaunchScreen.storyboard (see LaunchArtwork), so the
        // handoff from the system image has no seam. Created once here, never in
        // navigation callbacks.
        let cover = UIView()
        cover.accessibilityIdentifier = "launchCover"
        cover.accessibilityViewIsModal = true
        cover.backgroundColor = LaunchArtwork.canvas
        cover.translatesAutoresizingMaskIntoConstraints = false
        let mark = UIImageView(image: UIImage(named: "KoatLogo"))
        mark.contentMode = .scaleAspectFit
        mark.accessibilityLabel = "Koat"
        mark.isAccessibilityElement = true
        mark.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(mark)
        view.addSubview(cover)
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cover.topAnchor.constraint(equalTo: view.topAnchor),
            cover.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mark.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            NSLayoutConstraint(item: mark, attribute: .centerY, relatedBy: .equal, toItem: cover, attribute: .centerY, multiplier: LaunchArtwork.markCenterYMultiplier, constant: 0),
            mark.widthAnchor.constraint(equalToConstant: LaunchArtwork.markSize),
            mark.heightAnchor.constraint(equalToConstant: LaunchArtwork.markSize)
        ])
        launchCover = cover

        // Turbo draws progress for its visits. This bar covers document loads
        // and recovery, including progress above the initial launch artwork.
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.progressView.setProgress(Float(webView.estimatedProgress), animated: true)
        }
        dataStore.httpCookieStore.add(self)
        cookiesDidChange(in: dataStore.httpCookieStore)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bridgeDelegate.onViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bridgeDelegate.onViewDidAppear()
        recoverIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bridgeDelegate.onViewWillDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        bridgeDelegate.onViewDidDisappear()
    }

    /// Native entry points (push taps and sign-in). Ordinary links never pass here.
    func navigate(to url: URL, replacingDocument: Bool = false) {
        guard policy.isInternal(url) else { return }
        loadViewIfNeeded()
        if webView.isLoading {
            pendingNavigation = (url, replacingDocument)
            return
        }
        guard documentReady else {
            webView.load(URLRequest(url: url))
            return
        }
        // WebKit serializes arguments. Sign-in uses a fresh document to discard
        // the previous session's Turbo cache as well as replacing the login URL.
        webView.callAsyncJavaScript("""
            if (replaceDocument) {
                window.location.replace(url);
            } else if (window.Turbo) {
                window.Turbo.visit(url);
            } else {
                window.location.assign(url);
            }
            """, arguments: ["url": url.absoluteString, "replaceDocument": replacingDocument], in: nil, in: .page) { [weak self] result in
                if case .failure = result {
                    self?.webView.load(URLRequest(url: url))
                }
            }
    }

    func recoverIfNeeded() {
        guard needsRecovery, isViewLoaded, view.window != nil else { return }
        needsRecovery = false
        webView.load(URLRequest(url: webView.url ?? rootURL))
    }

    private func openExternal(_ url: URL) {
        guard presentedViewController == nil else { return }
        if ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            present(SFSafariViewController(url: url), animated: true)
        } else if ["mailto", "tel", "sms"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
        }
    }

    private func showLoadError(_ error: Error) {
        progressView.isHidden = true
        guard (error as NSError).code != NSURLErrorCancelled, presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Não foi possível carregar a página", message: "Verifique sua conexão e tente novamente.", preferredStyle: .alert)
        if launchCover == nil {
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        }
        alert.addAction(UIAlertAction(title: "Tentar novamente", style: .default) { [weak self] _ in
            guard let self else { return }
            let url = self.pendingNavigation?.url ?? self.retryURL ?? self.rootURL
            self.pendingNavigation = nil
            self.webView.load(URLRequest(url: url))
        })
        present(alert, animated: true)
    }

    /// The first page is ready underneath: let the mark lift away. The cover is
    /// forgotten immediately so later loads never bring it back; the animation
    /// owns the view until it is gone. With Reduce Motion the mark only fades.
    private func dismissLaunchCover() {
        guard let cover = launchCover else { return }
        launchCover = nil
        let mark = cover.subviews.first
        let liftsAway = !UIAccessibility.isReduceMotionEnabled
        UIView.animate(springDuration: LaunchArtwork.handoffDuration, bounce: 0, animations: {
            cover.alpha = 0
            if liftsAway {
                mark?.transform = CGAffineTransform(scaleX: LaunchArtwork.handoffScale, y: LaunchArtwork.handoffScale)
            }
        }, completion: { _ in
            cover.removeFromSuperview()
        })
    }
}

extension AppWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Also check the final response: a server redirect can change the origin.
        if navigationResponse.isForMainFrame, let url = navigationResponse.response.url, !policy.isInternal(url) {
            decisionHandler(.cancel)
            openExternal(url)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        // Frames may embed remote media; only top-level navigation leaves the shell.
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
        } else if policy.isInternal(url) {
            retryURL = url
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            openExternal(url)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        documentReady = false
        progressView.progress = 0
        progressView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        documentReady = true
        progressView.isHidden = true
        dismissLaunchCover()
        cookiesDidChange(in: dataStore.httpCookieStore)
        if let pending = pendingNavigation {
            pendingNavigation = nil
            navigate(to: pending.url, replacingDocument: pending.replacingDocument)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        documentReady = false
        needsRecovery = true
        if UIApplication.shared.applicationState == .active { recoverIfNeeded() }
    }
}

extension AppWebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, policy.isInternal(url) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard presentedViewController == nil else { completionHandler(); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard presentedViewController == nil else { completionHandler(false); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard presentedViewController == nil else { completionHandler(nil); return }
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in completionHandler(alert?.textFields?.first?.text) })
        present(alert, animated: true)
    }
}

extension AppWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let sourceURL = message.frameInfo.request.url, policy.isInternal(sourceURL) else { return }
        if message.name == "pageLoaded" {
            // WKHTTPCookieStore notifications can lag behind an HTTP-only login
            // cookie. Also check after Turbo renders and full document loads.
            cookiesDidChange(in: dataStore.httpCookieStore)
            return
        }
        guard message.name == "pdfExport" else { return }
        let value = (message.body as? [String: Any])?["url"] as? String ?? message.body as? String
        guard let value, let url = URL(string: value, relativeTo: webView.url)?.absoluteURL,
              policy.isInternal(url) else { return }
        pdfExportHandler.handlePDFExport(url: url.absoluteString)
    }
}

extension AppWebViewController: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let session = cookies.first { cookie in
                let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
                let host = self.rootURL.host?.lowercased()
                return cookie.name == "session_id" && (host == domain || host?.hasSuffix("." + domain) == true)
            }?.value
            guard session != self.lastSessionCookie else { return }
            self.lastSessionCookie = session
            if session != nil { self.sessionDidChange() }
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
