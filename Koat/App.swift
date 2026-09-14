import UIKit

@MainActor
final class App {
    static let shared = App()

    nonisolated static let baseURL: String = {
        #if DEBUG || (GOLDIE_CAPTURE && targetEnvironment(simulator))
        return "http://app.localhost:3000"
        #else
        return "https://app.koat.io"
        #endif
    }()

    private let rootURL: URL
    private let openExternalURL: @MainActor (URL) -> Void
    private var started = false
    private var pendingDeepLinkURL: URL?
    private(set) lazy var webViewController = AppWebViewController(rootURL: rootURL)

    var rootViewController: UIViewController { webViewController }

    init(rootURL: URL = URL(string: App.baseURL)!,
         openExternalURL: @escaping @MainActor (URL) -> Void = { UIApplication.shared.open($0) }) {
        self.rootURL = rootURL
        self.openExternalURL = openExternalURL
    }

    func start() {
        guard !started else { return }
        started = true
        let pendingURL = pendingDeepLinkURL
        pendingDeepLinkURL = nil
        if let pendingURL, WebNavigationPolicy(rootURL: rootURL).isInternal(pendingURL) {
            webViewController.navigate(to: pendingURL)
        } else {
            webViewController.navigate(to: rootURL)
            if let pendingURL { openExternalURL(pendingURL) }
        }
    }

    func handleDeepLink(path: String) {
        guard let url = URL(string: path, relativeTo: rootURL)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return }
        if started {
            if WebNavigationPolicy(rootURL: rootURL).isInternal(url) {
                webViewController.navigate(to: url)
            } else {
                openExternalURL(url)
            }
        } else {
            pendingDeepLinkURL = url
        }
    }

    func redeemSession(at url: URL) {
        webViewController.navigate(to: url, replacingDocument: true)
    }
}
