//
//  TabBarController.swift
//  Koat
//
//  Created by Assistant on 10/04/25.
//

import UIKit
import HotwireNative
import WebKit

class TabBarController: UITabBarController {
    private let app: App
    var treinoNavigator: Navigator!
    private var currentURL: URL?
    
    init(app: App) {
        self.app = app
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        
        // Start monitoring navigation changes
        startMonitoringNavigation()
    }
    
    private func startMonitoringNavigation() {
        // Use a timer to periodically check the current URL
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if let navController = self?.treinoNavigator.rootViewController as? UINavigationController,
               let visitable = navController.visibleViewController as? VisitableViewController {
                let currentURL = visitable.currentVisitableURL
                
                // Only update if URL changed
                if currentURL != self?.currentURL {
                    print("DEBUG: URL changed to: \(currentURL.absoluteString)")
                    self?.currentURL = currentURL
                    self?.updateTabBarVisibility(for: currentURL)
                }
            }
        }
    }
    
    private func updateTabBarVisibility(for url: URL) {
        print("DEBUG: updateTabBarVisibility called with URL: \(url.absoluteString), path: \(url.path)")
        
        // Hide tab bar for login and registration pages
        if url.path == "/session/new" || url.path == "/registration/new" {
            print("DEBUG: Hiding tab bar for auth page")
            tabBar.isHidden = true
            if let navController = treinoNavigator.rootViewController as? UINavigationController {
                navController.setNavigationBarHidden(true, animated: false)
            }
        } else {
            print("DEBUG: Showing tab bar for non-auth page")
            tabBar.isHidden = false
            if let navController = treinoNavigator.rootViewController as? UINavigationController {
                navController.setNavigationBarHidden(false, animated: false)
                navController.navigationBar.prefersLargeTitles = false
            }
        }
        
        print("DEBUG: Tab bar hidden state: \(tabBar.isHidden)")
    }
    
    func setupTabs() {
        // Create navigator for treino tab
        let startURL = URL(string: "\(App.baseURL)")!
        treinoNavigator = Navigator(configuration: .init(name: "treino", startLocation: startURL))
        treinoNavigator.delegate = self
        
        // Set initial URL
        currentURL = startURL
        
        // Configure tab bar items
        let treinoTab = treinoNavigator.rootViewController
        treinoTab.tabBarItem = UITabBarItem(title: "Treino", image: UIImage(systemName: "dumbbell"), tag: 0)
        
        // Create logout tab (this will be handled specially)
        let logoutViewController = UIViewController()
        logoutViewController.tabBarItem = UITabBarItem(title: "Sair", image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), tag: 1)
        
        // Set view controllers
        viewControllers = [treinoTab, logoutViewController]
        
        // Set delegate to handle tab selection
        delegate = self
        
        // Don't navigate immediately - let the App handle initial navigation
        // treinoNavigator.route(URL(string: "\(App.baseURL)")!)
        
        // Debug: Check for existing cookies after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            SessionManager.shared.logAllCookies(from: WKWebsiteDataStore.default())
        }
    }
}

// MARK: - NavigatorDelegate

extension TabBarController: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        print("TabBarController NavigatorDelegate: Handling proposal for URL: \(proposal.url.absoluteString), path: \(proposal.url.path)")
        
        // Store current URL
        currentURL = proposal.url
        
        // Update tab bar visibility based on the URL
        updateTabBarVisibility(for: proposal.url)
        
        // Handle logout
        if proposal.viewController == "logout" {
            app.performLogout()
            return .reject
        }
        
        // Handle presentation types from path configuration
        if let presentation = proposal.properties["presentation"] as? String,
           presentation == "replace" {
            // Clear the back stack after navigation
            DispatchQueue.main.async { [weak self] in
                if let navController = self?.treinoNavigator.rootViewController as? UINavigationController,
                   navController.viewControllers.count > 1 {
                    if let lastVC = navController.viewControllers.last {
                        navController.setViewControllers([lastVC], animated: false)
                    }
                }
            }
        }
        
        // Accept all other proposals with default behavior
        return .accept
    }
    
    func visitableDidRender() {
        print("TabBarController NavigatorDelegate: visitableDidRender called")
        
        // Check current URL after render
        DispatchQueue.main.async { [weak self] in
            if let navController = self?.treinoNavigator.rootViewController as? UINavigationController,
               let visitable = navController.visibleViewController as? VisitableViewController {
                let currentURL = visitable.currentVisitableURL
                print("DEBUG: visitableDidRender - Current URL: \(currentURL.absoluteString)")
                self?.updateTabBarVisibility(for: currentURL)
                self?.currentURL = currentURL
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // Check if this is the logout tab
        if viewController.tabBarItem.tag == 1 {
            // Show confirmation alert
            let alert = UIAlertController(
                title: "Sair",
                message: "Tem certeza que deseja sair?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
            
            alert.addAction(UIAlertAction(title: "Sair", style: .destructive) { [weak self] _ in
                // Perform logout
                self?.app.performLogout()
            })
            
            tabBarController.present(alert, animated: true, completion: nil)
            
            return false // Don't actually switch to this tab
        }
        return true
    }
}