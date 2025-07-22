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
    var profileNavigator: Navigator!
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
        
        // Hide tab bar initially until we know the user is authenticated
        tabBar.isHidden = true
        
        setupTabs()
        
        // Start monitoring navigation changes
        startMonitoringNavigation()
    }
    
    private func startMonitoringNavigation() {
        // Use a timer to periodically check the current URL
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            var currentURL: URL?
            
            // Check which tab is selected and get the current URL from the appropriate navigator
            if selectedIndex == 0 {
                // Treino tab
                let navController = self.treinoNavigator.rootViewController
                if let visitable = navController.visibleViewController as? VisitableViewController {
                    currentURL = visitable.currentVisitableURL
                }
            } else if selectedIndex == 1 {
                // Profile tab
                let navController = self.profileNavigator.rootViewController
                if let visitable = navController.visibleViewController as? VisitableViewController {
                    currentURL = visitable.currentVisitableURL
                }
            }
            
            // Only update if URL changed
            if let url = currentURL, url != self.currentURL {
                self.currentURL = url
                self.updateTabBarVisibility(for: url)
            }
        }
    }
    
    private func updateTabBarVisibility(for url: URL) {
        // List of authentication-related paths where tab bar should be hidden
        let authPaths = ["/session/new", "/registration/new", "/password/new", "/password/edit"]
        let shouldHideTabBar = authPaths.contains(url.path)
        
        if shouldHideTabBar {
            tabBar.isHidden = true
            // Hide navigation bar for both navigators
            treinoNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
            profileNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
        } else {
            tabBar.isHidden = false
            // Show navigation bar for both navigators
            treinoNavigator.rootViewController.setNavigationBarHidden(false, animated: false)
            treinoNavigator.rootViewController.navigationBar.prefersLargeTitles = false
            profileNavigator.rootViewController.setNavigationBarHidden(false, animated: false)
            profileNavigator.rootViewController.navigationBar.prefersLargeTitles = false
            
            // Update selected tab based on current URL
            updateSelectedTab(for: url)
        }
    }
    
    private func updateSelectedTab(for url: URL) {
        // Determine which tab should be selected based on the URL path
        if url.path.starts(with: "/settings/") {
            // Profile-related pages should select profile tab
            selectedIndex = 1
        } else {
            // All other pages (including home, workout plans, etc.) should select treino tab
            selectedIndex = 0
        }
    }
    
    func setupTabs() {
        // Create navigator for treino tab
        let startURL = URL(string: "\(App.baseURL)")!
        treinoNavigator = Navigator(configuration: .init(name: "treino", startLocation: startURL))
        treinoNavigator.delegate = self
        
        // Create navigator for profile tab - start with same URL as treino
        profileNavigator = Navigator(configuration: .init(name: "profile", startLocation: startURL))
        profileNavigator.delegate = self
        
        // Set initial URL
        currentURL = startURL
        
        // Configure tab bar items
        let treinoTab = treinoNavigator.rootViewController
        treinoTab.tabBarItem = UITabBarItem(title: "Treino", image: UIImage(systemName: "dumbbell"), tag: 0)
        
        let profileTab = profileNavigator.rootViewController
        profileTab.tabBarItem = UITabBarItem(title: "Perfil", image: UIImage(systemName: "person.circle"), tag: 1)
        
        // Hide navigation bar initially (will be shown when user is authenticated)
        treinoTab.setNavigationBarHidden(true, animated: false)
        profileTab.setNavigationBarHidden(true, animated: false)
        
        // Set view controllers
        viewControllers = [treinoTab, profileTab]
        
        // Configure tab bar appearance
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        // Fix tab bar background
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        
        // Set delegate to handle tab selection
        delegate = self
        
        // Start with treino tab selected
        selectedIndex = 0
        
        // Don't navigate immediately - let the App handle initial navigation
        // treinoNavigator.route(URL(string: "\(App.baseURL)")!")
    }
}

// MARK: - NavigatorDelegate

extension TabBarController: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        // Store current URL
        currentURL = proposal.url
        
        // Update tab bar visibility based on the URL
        updateTabBarVisibility(for: proposal.url)
        
        // Handle presentation types from path configuration
        if let presentation = proposal.properties["presentation"] as? String,
           presentation == "replace" {
            // Clear the back stack after navigation for the appropriate navigator
            DispatchQueue.main.async { [weak self] in
                // Determine which navigator to clear based on the URL
                let navigator = proposal.url.path.starts(with: "/settings/") ? self?.profileNavigator : self?.treinoNavigator
                
                if let navController = navigator?.rootViewController as? UINavigationController,
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
        // Check current URL after render for the active navigator
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var currentURL: URL?
            
            if selectedIndex == 0 {
                // Treino tab
                let navController = self.treinoNavigator.rootViewController
                if let visitable = navController.visibleViewController as? VisitableViewController {
                    currentURL = visitable.currentVisitableURL
                }
            } else if selectedIndex == 1 {
                // Profile tab
                let navController = self.profileNavigator.rootViewController
                if let visitable = navController.visibleViewController as? VisitableViewController {
                    currentURL = visitable.currentVisitableURL
                }
            }
            
            if let url = currentURL {
                self.updateTabBarVisibility(for: url)
                self.currentURL = url
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // Check if this is the profile tab
        if viewController.tabBarItem.tag == 1 {
            // Navigate to profile page when profile tab is selected
            profileNavigator.route(URL(string: "\(App.baseURL)/settings/profile")!)
        }
        return true
    }
}