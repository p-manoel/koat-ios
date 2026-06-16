//
//  ExternalLinkHandler.swift
//  Koat
//
//  Opens user-tapped external links with the system instead of Hotwire's
//  in-app Safari sheet, so universal links like wa.me reach WhatsApp
//  directly. Hotwire Native 1.2.1 keeps its route decision handlers
//  internal, so the interception happens in the page: a capture-phase click
//  listener runs before Turbo, forwards external http(s) anchors here, and
//  leaves everything else (same-host links, blob: downloads, tel:/mailto:,
//  form posts, redirect chains) to its default behavior.
//

import UIKit
import WebKit

final class ExternalLinkHandler: NSObject, WKScriptMessageHandler {
    static let shared = ExternalLinkHandler()
    static let messageName = "externalLink"

    // Active only on the app's own pages: on third-party pages (e.g. the
    // Google OAuth flow) every link is "external", including the ones leading
    // back into the app, and those must keep Hotwire's default routing.
    // Hostname comparison ignores the port so app.localhost:3000 works in dev.
    static let tapInterceptorScript: WKUserScript = {
        let appHost = URL(string: App.baseURL)?.host?.lowercased() ?? ""
        return WKUserScript(
            source: """
            (function() {
              var appHost = "\(appHost)";
              document.addEventListener("click", function(event) {
                if (window.location.hostname.toLowerCase() !== appHost) { return; }
                var target = event.target instanceof Element ? event.target : null;
                var anchor = target && target.closest("a[href]");
                if (!anchor) { return; }
                if (anchor.protocol !== "http:" && anchor.protocol !== "https:") { return; }
                if (anchor.hostname.toLowerCase() === appHost) { return; }
                event.preventDefault();
                event.stopImmediatePropagation();
                window.webkit.messageHandlers.externalLink.postMessage(anchor.href);
              }, true);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }()

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let urlString = message.body as? String,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }
        UIApplication.shared.open(url)
    }
}
