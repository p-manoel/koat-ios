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
    var currentRole: String?
    
    // Dynamic navigator storage - keyed by tab id
    private var navigators: [String: Navigator] = [:]
    
    // Store tab configurations for dynamic tab handling
    private var tabConfigurations: [TabConfiguration] = []
    
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
        tabBar.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startNavigationMonitoring()
    }
    
    private func startNavigationMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.app.sceneDelegate?.window?.rootViewController !== self {
                timer.invalidate()
                return
            }
            
            if let visitable = self.getCurrentVisitable() {
                let currentPath = visitable.currentVisitableURL.path
                if currentPath == "/session/new" {
                    timer.invalidate()
                    App.shared.performLogout()
                }
            }
        }
    }
    
    // Dynamic tab configuration from server
    func setupWithConfiguration(_ tabs: [TabConfiguration], role: String, with navigator: Navigator) {
        self.currentRole = role
        self.tabConfigurations = tabs
        
        UserDefaults.standard.set(role, forKey: "userRole")
        
        navigators.removeAll()
        
        var tabViewControllers: [UIViewController] = []
        
        for (index, tab) in tabs.enumerated() {
            let url = URL(string: "\(App.baseURL)\(tab.path)")!
            let nav = Navigator(configuration: .init(name: tab.id, startLocation: url))
            nav.delegate = self
            
            let tabVC = nav.rootViewController
            tabVC.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.icon),
                tag: index
            )
            
            tabViewControllers.append(tabVC)
            navigators[tab.id] = nav
        }
        
        if let firstTab = tabs.first {
            currentURL = URL(string: "\(App.baseURL)\(firstTab.path)")
        }
        
        viewControllers = tabViewControllers
        
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        
        delegate = self
        selectedIndex = 0
        
        // Tab bar visibility is controlled by Rails path configuration
        tabBar.isHidden = false
        
        for tab in tabs {
            if let nav = navigators[tab.id] {
                let url = URL(string: "\(App.baseURL)\(tab.path)")!
                nav.route(url)
            }
        }
        
        if role == "client" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for nav in self.navigators.values {
                    nav.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            }
        }
    }
    
    // MARK: - Navigator Access
    
    func navigator(forTabId tabId: String) -> Navigator? {
        return navigators[tabId]
    }
    
    func clearNavigators() {
        for nav in navigators.values {
            nav.session.webView.stopLoading()
        }
        
        navigators.removeAll()
        tabConfigurations.removeAll()
        currentURL = nil
        currentRole = nil
    }
    
    func currentNavigator() -> Navigator? {
        guard selectedIndex < tabConfigurations.count else { return nil }
        let tabId = tabConfigurations[selectedIndex].id
        return navigators[tabId]
    }
    
    /// Navigate to a specific URL (used for deep links from push notifications)
    func navigateToURL(_ url: URL) {
        // First, find which tab this URL belongs to
        if let index = tabIndex(forPath: url.path), index < tabConfigurations.count {
            let tabId = tabConfigurations[index].id
            
            // Switch to the correct tab
            selectedIndex = index
            
            // Navigate within that tab's navigator
            if let navigator = navigators[tabId] {
                navigator.route(url)
            }
        } else if let navigator = currentNavigator() {
            // Fallback: navigate in current tab
            navigator.route(url)
        }
    }
    
    private func tabIndex(forPath path: String) -> Int? {
        for (index, tab) in tabConfigurations.enumerated() {
            if tab.path == "/" {
                continue
            }
            if path.starts(with: tab.path) {
                return index
            }
        }
        return 0
    }
    
    /// Updates tab bar visibility based on Rails path configuration
    private func updateTabBarVisibility(for url: URL) {
        let properties = Hotwire.config.pathConfiguration.properties(for: url)
        let shouldHideTabBar = properties["hide_tab_bar"] as? Bool ?? false
        
        tabBar.isHidden = shouldHideTabBar
        
        if !shouldHideTabBar {
            updateSelectedTab(for: url)
        }
    }
    
    private func updateSelectedTab(for url: URL) {
        if let index = tabIndex(forPath: url.path) {
            selectedIndex = index
        }
    }
}

// MARK: - NavigatorDelegate

extension TabBarController: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        if proposal.url.path == "/session/new" {
            App.shared.performLogout()
            return .reject
        }

        currentURL = proposal.url
        updateTabBarVisibility(for: proposal.url)
        
        if let context = proposal.properties["context"] as? String, context == "modal" {
            return .accept
        }
        
        if let presentation = proposal.properties["presentation"] as? String {
            switch presentation {
            case "replace":
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          let index = self.tabIndex(forPath: proposal.url.path),
                          index < self.tabConfigurations.count else { return }
                    
                    let tabId = self.tabConfigurations[index].id
                    if let navigator = self.navigators[tabId],
                       let navController = navigator.rootViewController as? UINavigationController,
                       navController.viewControllers.count > 1,
                       let lastVC = navController.viewControllers.last {
                        navController.setViewControllers([lastVC], animated: false)
                    }
                }
                return .accept
            default:
                return .accept
            }
        }
        
        return .accept
    }
    
    private func getCurrentVisitable() -> VisitableViewController? {
        guard let nav = currentNavigator() else { return nil }
        return nav.rootViewController.visibleViewController as? VisitableViewController
    }
    
    func navigatorDidFinishNavigation(_ navigator: Navigator) {
        guard let visitable = getCurrentVisitable() else { return }
        let url = visitable.currentVisitableURL
        
        if url.path == "/session/new" {
            App.shared.performLogout()
            return
        }

        updateTabBarVisibility(for: url)
    }
    
    func visitableDidRender() {
        guard let nav = currentNavigator(),
              let visitable = nav.rootViewController.visibleViewController as? VisitableViewController else { return }
        
        let url = visitable.currentVisitableURL
        currentURL = url
        
        if url.path == "/session/new" {
            App.shared.performLogout()
            return
        }

        updateTabBarVisibility(for: url)
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let tag = viewController.tabBarItem.tag
        
        guard tag < tabConfigurations.count else {
            return true
        }
        
        let tab = tabConfigurations[tag]
        let url = URL(string: "\(App.baseURL)\(tab.path)")!
        
        if let navigator = navigators[tab.id] {
            navigator.route(url)
            
            if currentRole == "client" {
                DispatchQueue.main.async {
                    navigator.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            }
        }
        return true
    }
}
