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
        // Create PDF export handler
        pdfExportHandler = PDFExportHandler(presentingViewController: self)

        // Register message handler with the webView
        if let webView = visitableView.webView,
           let handler = pdfExportHandler {
            // Remove any existing handler to avoid duplicates
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pdfExport")
            // Add the new handler
            webView.configuration.userContentController.add(handler, name: "pdfExport")
        }
    }

    deinit {
        // Clean up message handler
        if let webView = visitableView.webView {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pdfExport")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Update again in case the navigation controller wasn't ready in viewWillAppear
        updateNavigationBarVisibility(animated: false)
    }
    
    private func updateNavigationBarVisibility(animated: Bool) {
        // Get path configuration properties for current URL
        let properties = Hotwire.config.pathConfiguration.properties(for: currentVisitableURL)

        // Check if navigation bar should be hidden
        let navigationBarHidden = properties["navigation_bar_hidden"] as? Bool ?? false

        // Special handling for tab roots - force hide navigation bar
        // Only hide for exact root tab paths, not for nested routes like edit pages
        let tabRootPaths = [
            "/",                                      // Treino (workout) tab root
            "/clients",                               // Clients tab root
            "/exercises",                             // Exercises tab root
            "/meal_plans",                            // Meal plans tab root
            "/anthropometric_assessments",            // Assessments tab root
            "/anthropometric_assessments/comparison", // Evolution tab root
            "/settings/profile"                       // Profile settings tab root
        ]
        if tabRootPaths.contains(currentVisitableURL.path) {
            navigationController?.setNavigationBarHidden(true, animated: animated)
            #if DEBUG
            print("AppWebViewController - Force hiding nav for client tab - URL: \(currentVisitableURL.absoluteString)")
            #endif
            return
        }

        // Apply navigation bar visibility
        navigationController?.setNavigationBarHidden(navigationBarHidden, animated: animated)

        #if DEBUG
        print("AppWebViewController - URL: \(currentVisitableURL.absoluteString) - Nav Hidden: \(navigationBarHidden)")
        print("AppWebViewController - Properties: \(properties)")
        #endif
    }
    
    override func visitableDidRender() {
        super.visitableDidRender()

        // Update navigation bar visibility after page renders
        updateNavigationBarVisibility(animated: false)
    }
}