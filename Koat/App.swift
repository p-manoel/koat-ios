import UIKit

@MainActor
final class App {
    static let shared = App()

    nonisolated static let baseURL: String = {
        #if DEBUG
        return "http://app.localhost:3000"
        #else
        return "https://app.koat.io"
        #endif
    }()

    private let rootURL = URL(string: baseURL)!
    private var started = false
    private var pendingDeepLinkURL: URL?
    private(set) lazy var webViewController = AppWebViewController(rootURL: rootURL)

    var rootViewController: UIViewController { webViewController }

    func start() {
        guard !started else { return }
        started = true
        webViewController.navigate(to: pendingDeepLinkURL ?? rootURL)
        pendingDeepLinkURL = nil
    }

    func handleDeepLink(path: String) {
        guard let url = URL(string: path, relativeTo: rootURL)?.absoluteURL,
              WebNavigationPolicy(rootURL: rootURL).isInternal(url) else { return }
        if started {
            webViewController.navigate(to: url)
        } else {
            pendingDeepLinkURL = url
        }
    }

    func redeemSession(at url: URL) {
        webViewController.navigate(to: url, replacingDocument: true)
    }
}
