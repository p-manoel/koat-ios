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

#if DEBUG
    // TEMPORARY smoke-test affordance: a floating "G" button that opens the
    // native Google sheet so we can verify the SDK/URL-scheme/OAuth-client wiring
    // on device. Remove once the Hotwire Native bridge component drives sign-in
    // from the web login button. DEBUG builds only.
    private lazy var debugGoogleSignInButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "G"
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            GoogleAuth.signIn(presenting: self) { result in
                switch result {
                case .success(let idToken):
                    print("[GoogleAuth] received idToken (\(idToken.count) chars): \(idToken.prefix(24))…")
                case .failure(let error):
                    print("[GoogleAuth] sign-in failed: \(error)")
                }
            }
        }, for: .primaryActionTriggered)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(debugGoogleSignInButton)
        NSLayoutConstraint.activate([
            debugGoogleSignInButton.widthAnchor.constraint(equalToConstant: 44),
            debugGoogleSignInButton.heightAnchor.constraint(equalToConstant: 44),
            debugGoogleSignInButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            debugGoogleSignInButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -88)
        ])
    }
#endif

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
