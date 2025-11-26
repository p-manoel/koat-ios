//
//  AppWebViewController.swift
//  Koat
//
//  Custom WebViewController to handle navigation bar visibility
//

import UIKit
import HotwireNative
import WebKit

class AppWebViewController: HotwireWebViewController {

    private var pdfExportHandler: PDFExportHandler?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPDFExportHandler()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationBarVisibility(animated: animated)
    }

    private func setupPDFExportHandler() {
        pdfExportHandler = PDFExportHandler(presentingViewController: self)

        if let webView = visitableView.webView,
           let handler = pdfExportHandler {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pdfExport")
            webView.configuration.userContentController.add(handler, name: "pdfExport")
        }
    }

    deinit {
        if let webView = visitableView.webView {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pdfExport")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateNavigationBarVisibility(animated: false)
        // Note: Tab bar visibility is controlled by TabBarController based on Rails path configuration
    }
    
    private func updateNavigationBarVisibility(animated: Bool) {
        // Get navigation bar visibility from Rails path configuration
        let properties = Hotwire.config.pathConfiguration.properties(for: currentVisitableURL)
        let navigationBarHidden = properties["navigation_bar_hidden"] as? Bool ?? false

        // Special handling for subscription page - check subscription status
        if currentVisitableURL.path == "/subscriptions/select_plan" {
            checkSubscriptionStatusAndUpdateNavigationBar(animated: animated)
            return
        }

        // Apply navigation bar visibility from Rails path configuration
        navigationController?.setNavigationBarHidden(navigationBarHidden, animated: animated)
    }
    
    override func visitableDidRender() {
        super.visitableDidRender()
        updateNavigationBarVisibility(animated: false)
        // Note: Tab bar visibility is controlled by TabBarController based on Rails path configuration
    }

    private func checkSubscriptionStatusAndUpdateNavigationBar(animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            self.visitableView.webView?.evaluateJavaScript("document.querySelector('meta[name=\"subscription-status\"]')?.content") { [weak self] result, error in
                guard let self = self else { return }

                let subscriptionStatus = result as? String

                DispatchQueue.main.async {
                    if subscriptionStatus == "active" {
                        self.navigationController?.setNavigationBarHidden(false, animated: animated)

                        let backButton = UIBarButtonItem(
                            image: UIImage(systemName: "chevron.left"),
                            style: .plain,
                            target: self,
                            action: #selector(self.backButtonTapped)
                        )
                        self.navigationItem.leftBarButtonItem = backButton
                    } else {
                        self.navigationController?.setNavigationBarHidden(true, animated: animated)
                        self.navigationItem.leftBarButtonItem = nil
                    }
                }
            }
        }
    }

    @objc private func backButtonTapped() {
        let profileURL = URL(string: "\(App.baseURL)/settings/profile")!
        visitableView.webView?.evaluateJavaScript("window.location.href = '\(profileURL.absoluteString)'")
    }
}
