import Foundation

/// Only the app's origin may occupy the authenticated web view.
struct WebNavigationPolicy {
    let rootURL: URL

    func isInternal(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return false }
        return scheme == rootURL.scheme?.lowercased()
            && url.host?.lowercased() == rootURL.host?.lowercased()
            && effectivePort(url) == effectivePort(rootURL)
            && url.user == nil && url.password == nil
    }

    private func effectivePort(_ url: URL) -> Int {
        url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
    }
}
