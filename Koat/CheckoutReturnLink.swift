import Foundation

/// Checkout callbacks carry navigation only. Rails authenticates the user and
/// verifies payment. Never forward a callback's host, query or fragment.
struct CheckoutReturnLink {
    let rootURL: URL

    func destination(for url: URL) -> URL? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.fragment == nil else { return nil }
        let id: String
        if parts.scheme == "koat" {
            guard parts.host == "checkout-return", parts.port == nil, parts.query == nil,
                  let value = capture(parts.percentEncodedPath, pattern: #"^/([0-9]+)$"#) else { return nil }
            id = value
        } else {
            guard parts.scheme == "https", WebNavigationPolicy(rootURL: rootURL).isInternal(url),
                  parts.queryItems?.filter({ $0.name == "app_return" }).map(\.value) == ["ios"],
                  !((parts.queryItems ?? []).contains { $0.name == "browser" }),
                  let value = capture(parts.percentEncodedPath, pattern: #"^/subscriptions/checkouts/([0-9]+)/return$"#) else { return nil }
            id = value
        }
        return URL(string: "/subscriptions/checkouts/\(id)/return", relativeTo: rootURL)?.absoluteURL
    }

    func recoveryURL(from source: URL?) -> URL {
        if let source, WebNavigationPolicy(rootURL: rootURL).isInternal(source),
           let id = capture(source.path, pattern: #"^/subscriptions/checkouts/([0-9]+)(?:/return)?$"#) {
            return rootURL.appendingPathComponent("subscriptions/checkouts/\(id)/return")
        }
        let path = source?.path.hasPrefix("/onboarding") == true ? "onboarding" : "subscriptions"
        return rootURL.appendingPathComponent(path)
    }

    private func capture(_ path: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let range = Range(match.range(at: 1), in: path) else { return nil }
        return String(path[range])
    }
}
