//
//  PDFExportHandler.swift
//  Koat
//
//  Handles PDF export messages from JavaScript
//

import UIKit
import WebKit

class PDFExportHandler: NSObject {

    weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
        super.init()
    }

    func handlePDFExport(url: String) {
        guard let pdfURL = URL(string: url) else {
            return
        }

        // Get cookies from WebView for authentication
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }

            // Filter cookies for our domain
            let relevantCookies = cookies.filter { cookie in
                return pdfURL.host?.contains(cookie.domain) ?? false ||
                       cookie.domain.contains(".koat.io") ||
                       cookie.domain.contains("localhost")
            }

            // Get the current view controller for presentation
            guard let viewController = self.presentingViewController else {
                return
            }

            // Create PDF download handler and handle the download
            let pdfHandler = PDFDownloadHandler(presentingViewController: viewController)
            pdfHandler.handlePDFDownload(from: pdfURL, cookies: relevantCookies)
        }
    }
}

// MARK: - WKScriptMessageHandler
extension PDFExportHandler: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "pdfExport" else { return }

        // Extract URL from message
        if let body = message.body as? [String: Any],
           let url = body["url"] as? String {
            handlePDFExport(url: url)
        } else if let url = message.body as? String {
            handlePDFExport(url: url)
        }
    }
}