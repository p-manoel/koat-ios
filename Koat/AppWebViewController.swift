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
        updateTabBarVisibility()
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

        // Special handling for subscription page - check subscription status
        if currentVisitableURL.path == "/subscriptions/select_plan" {
            checkSubscriptionStatusAndUpdateNavigationBar(animated: animated)
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
        updateTabBarVisibility()
    }

    private func updateTabBarVisibility() {
        // Get path configuration properties for current URL
        let properties = Hotwire.config.pathConfiguration.properties(for: currentVisitableURL)

        // Check if this page has the hide_tab_bar property
        if let hideTabBar = properties["hide_tab_bar"] as? Bool, hideTabBar {
            // For subscription page, check meta tag to see if user has access
            if currentVisitableURL.path == "/subscriptions/select_plan" {
                checkSubscriptionStatusAndUpdateTabBar()
            } else {
                // Other pages with hide_tab_bar: true - hide unconditionally
                #if DEBUG
                print("AppWebViewController - Hiding tab bar for: \(currentVisitableURL.path)")
                #endif

                if let tabBarController = findTabBarController() {
                    DispatchQueue.main.async {
                        tabBarController.tabBar.isHidden = true
                    }
                }
            }
        } else {
            #if DEBUG
            print("AppWebViewController - Showing tab bar for: \(currentVisitableURL.path)")
            #endif

            // Show tab bar again when navigating to normal pages
            if let tabBarController = findTabBarController() {
                DispatchQueue.main.async {
                    tabBarController.tabBar.isHidden = false
                }
            }
        }
    }

    private func checkSubscriptionStatusAndUpdateNavigationBar(animated: Bool) {
        // Add small delay to ensure meta tag is in DOM
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // Read meta tag from page to determine subscription status
            self.visitableView.webView?.evaluateJavaScript("document.querySelector('meta[name=\"subscription-status\"]')?.content") { [weak self] result, error in
                guard let self = self else { return }

                let subscriptionStatus = result as? String

                #if DEBUG
                print("AppWebViewController - Subscription status for nav bar: \(subscriptionStatus ?? "nil") for URL: \(self.currentVisitableURL.path)")
                #endif

                DispatchQueue.main.async {
                    if subscriptionStatus == "active" {
                        // Active trial or paid subscription - show navigation bar with back button
                        #if DEBUG
                        print("AppWebViewController - Showing navigation bar with back button (active)")
                        #endif
                        self.navigationController?.setNavigationBarHidden(false, animated: animated)

                        // Add custom back button since presentation: replace clears navigation stack
                        let backButton = UIBarButtonItem(
                            image: UIImage(systemName: "chevron.left"),
                            style: .plain,
                            target: self,
                            action: #selector(self.backButtonTapped)
                        )
                        self.navigationItem.leftBarButtonItem = backButton
                    } else {
                        // Expired or no subscription - hide navigation bar
                        #if DEBUG
                        print("AppWebViewController - Hiding navigation bar (expired/no access)")
                        #endif
                        self.navigationController?.setNavigationBarHidden(true, animated: animated)
                        self.navigationItem.leftBarButtonItem = nil
                    }
                }
            }
        }
    }

    private func checkSubscriptionStatusAndUpdateTabBar() {
        // Read meta tag from page to determine subscription status
        visitableView.webView?.evaluateJavaScript("document.querySelector('meta[name=\"subscription-status\"]')?.content") { [weak self] result, error in
            guard let self = self else { return }

            let subscriptionStatus = result as? String

            #if DEBUG
            print("AppWebViewController - Subscription status for tab bar: \(subscriptionStatus ?? "nil")")
            #endif

            // Hide tab bar only if subscription is expired (no access)
            let shouldHideTabBar = subscriptionStatus == "expired"

            #if DEBUG
            print("AppWebViewController - Should hide tab bar on subscription page: \(shouldHideTabBar)")
            #endif

            if let tabBarController = self.findTabBarController() {
                DispatchQueue.main.async {
                    tabBarController.tabBar.isHidden = shouldHideTabBar
                }
            }
        }
    }

    private func findTabBarController() -> UITabBarController? {
        var currentVC: UIViewController? = self
        while let vc = currentVC {
            if let tabBarController = vc.tabBarController {
                return tabBarController
            }
            currentVC = vc.parent
        }
        return nil
    }

    @objc private func backButtonTapped() {
        // Navigate back from subscription page to profile
        #if DEBUG
        print("AppWebViewController - Back button tapped on subscription page")
        #endif

        // Navigate to profile page
        let profileURL = URL(string: "\(App.baseURL)/settings/profile")!

        #if DEBUG
        print("AppWebViewController - Navigating to: \(profileURL.absoluteString)")
        #endif

        visitableView.webView?.evaluateJavaScript("window.location.href = '\(profileURL.absoluteString)'")
    }
}