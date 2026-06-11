//
//  AppWebViewController.swift
//  Koat
//
//  Chromeless web view controller: no native bars, web content edge-to-edge.
//

import HotwireNative
import UIKit
import WebKit

final class AppWebViewController: HotwireWebViewController {
    private var pdfExportHandler: PDFExportHandler?
    private lazy var koatSpinner = KoatSpinnerView()

    // Replace the default gray UIActivityIndicatorView with the Koat-branded
    // spinner. Not calling super keeps the default indicator stopped (it is
    // hidesWhenStopped) so only ours ever shows.
    override func showVisitableActivityIndicator() {
        guard !visitableView.isRefreshing else { return }

        if koatSpinner.superview == nil {
            visitableView.addSubview(koatSpinner)
            NSLayoutConstraint.activate([
                koatSpinner.centerXAnchor.constraint(equalTo: visitableView.centerXAnchor),
                koatSpinner.centerYAnchor.constraint(equalTo: visitableView.centerYAnchor)
            ])
        }
        koatSpinner.startAnimating()
        visitableView.bringSubviewToFront(koatSpinner)
    }

    override func hideVisitableActivityIndicator() {
        koatSpinner.stopAnimating()
    }

    // Backstop: the bar is already hidden by ChromelessNavigationController,
    // but never allow anything to re-show it.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // Called every time the (per-session, shared) web view attaches to this
    // screen — the only safe moment to install per-screen web view hooks.
    override func visitableDidActivateWebView(_ webView: WKWebView) {
        super.visitableDidActivateWebView(webView)

        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let handler = PDFExportHandler(presentingViewController: self)
        pdfExportHandler = handler
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "pdfExport")
        webView.configuration.userContentController.add(handler, name: "pdfExport")
    }

    // Deactivation of the old screen always precedes activation of the next,
    // so removing here never clobbers a newer screen's handler (unlike deinit).
    override func visitableWillDeactivateWebView() {
        visitableView.webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: "pdfExport")
        super.visitableWillDeactivateWebView()
    }
}
