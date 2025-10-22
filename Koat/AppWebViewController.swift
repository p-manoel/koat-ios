//
//  AppWebViewController.swift
//  Koat
//
//  Custom WebViewController to handle navigation bar visibility
//

import UIKit
import HotwireNative

class AppWebViewController: HotwireWebViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationBarVisibility(animated: animated)
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

        // Special handling for client tabs - force hide navigation bar
        let clientTabPaths = ["/anthropometric_assessments", "/meal_plans", "/settings/profile"]
        if clientTabPaths.contains(where: { currentVisitableURL.path.contains($0) }) || currentVisitableURL.path == "/" {
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