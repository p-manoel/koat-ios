//
//  WebViewUIHandler.swift
//  Koat
//
//  WKUIDelegate for the Turbo session's web view: native panels for JS
//  alert/confirm/prompt (window.confirm drives Turbo's data-turbo-confirm)
//  and window.open/target="_blank" handling. Hotwire Native's Session only
//  claims navigationDelegate, so uiDelegate is free for the app; the web
//  view holds it weakly, hence the shared singleton.
//

import UIKit
import WebKit

final class WebViewUIHandler: NSObject, WKUIDelegate {
    static let shared = WebViewUIHandler()

    private let appHost = URL(string: App.baseURL)?.host?.lowercased()

    // target="_blank" and window.open land here. Same-host links (blob files,
    // exports) stay in the web view to keep the session; everything else goes
    // to the system so universal links open WhatsApp/App Store directly.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(),
              scheme != "about" else { return nil }

        if (scheme == "http" || scheme == "https") && url.host?.lowercased() == appHost {
            webView.load(navigationAction.request)
        } else {
            UIApplication.shared.open(url)
        }
        // Never return the passed-in web view: WebKit requires the result to
        // be created with the given configuration and crashes otherwise.
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert) { completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert) { completionHandler(false) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text ?? "")
        })
        present(alert) { completionHandler(nil) }
    }

    // Present above whatever is frontmost (a Turbo screen, a modal stack, or
    // the PDF progress alert). The fallback runs the panel's cancel path when
    // presenting is impossible, so page JavaScript never hangs on a dropped
    // completion handler.
    private func present(_ alert: UIAlertController, fallback: () -> Void) {
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else {
            fallback()
            return
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(alert, animated: true)
    }
}
