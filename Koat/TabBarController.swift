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
    
    // Temporary navigator for initial load
    var tempNavigator: Navigator!
    
    // Client navigators
    var treinoNavigator: Navigator!
    var dietaNavigator: Navigator!
    var manipuladosNavigator: Navigator!
    var evolucaoNavigator: Navigator!
    var profileNavigator: Navigator!
    
    // Coach navigators
    var clientsNavigator: Navigator!
    var exercisesNavigator: Navigator!
    var coachProfileNavigator: Navigator!
    
    private var currentURL: URL?
    private var navigationTimer: Timer?
    
    init(app: App) {
        self.app = app
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Tab bar will be configured when setupForRole is called
        tabBar.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start monitoring navigation
        startNavigationMonitoring()
    }
    
    private func startNavigationMonitoring() {
        // Monitor navigation changes every 0.5 seconds
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Check if we're still the root view controller
            if self.app.sceneDelegate?.window?.rootViewController !== self {
                timer.invalidate()
                return
            }
            
            // Check current URL of active navigator
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
        
        // Store the role
        UserDefaults.standard.set(role, forKey: "userRole")
        
        // Store navigators by tab id for later reference
        var navigators: [String: Navigator] = [:]
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
            
            // Store navigator references based on tab id
            switch tab.id {
            case "clients":
                clientsNavigator = nav
            case "exercises":
                exercisesNavigator = nav
            case "profile":
                if role == "coach" {
                    coachProfileNavigator = nav
                } else {
                    profileNavigator = nav
                }
            case "treino":
                treinoNavigator = nav
            case "dieta":
                dietaNavigator = nav
            case "manipulados":
                manipuladosNavigator = nav
            case "evolucao":
                evolucaoNavigator = nav
            default:
                break
            }
        }
        
        // Set initial URL
        if let firstTab = tabs.first {
            currentURL = URL(string: "\(App.baseURL)\(firstTab.path)")
        }
        
        // Set view controllers
        viewControllers = tabViewControllers
        
        // Configure tab bar appearance
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        
        // Set delegate to handle tab selection
        delegate = self
        
        // Start with first tab selected
        selectedIndex = 0
        
        // Keep tab bar hidden initially - will be shown after first successful navigation
        tabBar.isHidden = true
        
        // Navigate to initial URLs for each navigator
        for (tabId, nav) in navigators {
            if let tab = tabs.first(where: { $0.id == tabId }) {
                let url = URL(string: "\(App.baseURL)\(tab.path)")!
                nav.route(url)
            }
        }
        
        // Hide navigation bars for all tabs if client
        if role == "client" {
            DispatchQueue.main.async { [weak self] in
                for nav in navigators.values {
                    nav.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            }
        }
        
        // Store tabs configuration for tab selection handling
        self.tabConfigurations = tabs
    }
    
    // Store tab configurations for dynamic tab selection
    private var tabConfigurations: [TabConfiguration] = []
    
    private func startMonitoringNavigation() {
        // Use a timer to periodically check the current URL
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            var currentURL: URL?
            
            // Check which tab is selected and get the current URL from the appropriate navigator
            if currentRole == "client" {
                if selectedIndex == 0 {
                    // Treino tab
                    let navController = self.treinoNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 1 {
                    // Dieta tab
                    let navController = self.dietaNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 2 {
                    // Manipulados tab
                    let navController = self.manipuladosNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 3 {
                    // Evolucao tab
                    let navController = self.evolucaoNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 4 {
                    // Profile tab
                    let navController = self.profileNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                }
            } else if currentRole == "coach" {
                if selectedIndex == 0 {
                    // Clients tab
                    let navController = self.clientsNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 1 {
                    // Exercises tab
                    let navController = self.exercisesNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 2 {
                    // Profile tab
                    let navController = self.coachProfileNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
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
        // Get hide_tab_bar property from path configuration (controlled by Rails)
        let properties = Hotwire.config.pathConfiguration.properties(for: url)
        let shouldHideTabBar = properties["hide_tab_bar"] as? Bool ?? false

        #if DEBUG
        print("TabBarController - updateTabBarVisibility - URL: \(url.path) - Should hide: \(shouldHideTabBar)")
        #endif

        if shouldHideTabBar {
            tabBar.isHidden = true
            // Hide navigation bar for all navigators
            hideAllNavigationBars()
        } else if currentRole != nil {
            // Only show tab bar if user has a role
            tabBar.isHidden = false
            // Update selected tab based on current URL
            updateSelectedTab(for: url)
        }
    }
    
    private func hideAllNavigationBars() {
        // This method is called when on authentication pages
        // We should actually hide the navigation bars in this case
        if currentRole == "client" {
            treinoNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
            dietaNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
            manipuladosNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
            evolucaoNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
            profileNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
        } else if currentRole == "coach" {
            clientsNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
            exercisesNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
            coachProfileNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
        }
    }
    
    private func showAllNavigationBars() {
        if currentRole == "client" {
            treinoNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            treinoNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
            dietaNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            dietaNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
            manipuladosNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            manipuladosNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
            evolucaoNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            evolucaoNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
            profileNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            profileNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
        } else if currentRole == "coach" {
            clientsNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            clientsNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
            exercisesNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            exercisesNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
            coachProfileNavigator?.rootViewController.setNavigationBarHidden(false, animated: false)
            coachProfileNavigator?.rootViewController.navigationBar.prefersLargeTitles = false
        }
    }
    
    
    private func updateSelectedTab(for url: URL) {
        // Determine which tab should be selected based on the URL path
        if currentRole == "client" {
            if url.path.starts(with: "/meal_plans") {
                // Dieta tab
                selectedIndex = 1
            } else if url.path.starts(with: "/compounds_plans") {
                // Manipulados tab
                selectedIndex = 2
            } else if url.path.starts(with: "/anthropometric_assessments") {
                // Anthropometric assessment pages should select evolucao tab
                selectedIndex = 3
            } else if url.path.starts(with: "/settings/") {
                // Profile-related pages should select profile tab
                selectedIndex = 4
            } else {
                // All other pages (including home, workout plans, etc.) should select treino tab
                selectedIndex = 0
            }
        } else if currentRole == "coach" {
            if url.path.starts(with: "/clients") {
                selectedIndex = 0
            } else if url.path.starts(with: "/exercises") {
                selectedIndex = 1
            } else if url.path.starts(with: "/settings/") {
                selectedIndex = 2
            } else {
                // Default to clients tab for other URLs
                selectedIndex = 0
            }
        }
    }
    
    
}

// MARK: - NavigatorDelegate

extension TabBarController: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        // Check if navigating to login page - if so, trigger logout
        if proposal.url.path == "/session/new" || proposal.url.path.starts(with: "/registration") {
            // Immediately hide the tab bar and clear state
            self.tabBar.isHidden = true
            self.currentRole = nil
            self.viewControllers = []

            // Call App's performLogout to properly clean up and switch back to single navigator
            App.shared.performLogout()
            // Reject this proposal since performLogout will handle the navigation properly
            return .reject
        }

        // Store current URL
        currentURL = proposal.url

        // Check if tab bar should be hidden based on path configuration
        if let hideTabBar = proposal.properties["hide_tab_bar"] as? Bool, hideTabBar {
            #if DEBUG
            print("TabBarController - Hiding tab bar due to hide_tab_bar property for: \(proposal.url.path)")
            #endif
            DispatchQueue.main.async {
                self.tabBar.isHidden = true
            }
        } else {
            // Check if navigating away from a page that had hide_tab_bar
            if let prevURL = currentURL {
                let prevProperties = Hotwire.config.pathConfiguration.properties(for: prevURL)
                let prevHideTabBar = prevProperties["hide_tab_bar"] as? Bool ?? false
                
                if prevHideTabBar && currentRole != nil {
                    #if DEBUG
                    print("TabBarController - Showing tab bar when navigating away from hidden tab bar page")
                    #endif
                    DispatchQueue.main.async {
                        self.tabBar.isHidden = false
                    }
                }
            }
        }

        // Update tab bar visibility based on the URL
        updateTabBarVisibility(for: proposal.url)
        
        // Check if context is modal (standard Hotwire Native approach)
        if let context = proposal.properties["context"] as? String,
           context == "modal" {
            // Accept the proposal - Hotwire Native will handle modal presentation automatically
            return .accept
        }
        
        // Handle presentation types from path configuration
        if let presentation = proposal.properties["presentation"] as? String {
            switch presentation {
            case "modal":
                // Accept the proposal - let Hotwire Native handle it
                // The Navigator will automatically present as modal when context is "modal"
                return .accept
                
            case "push":
                return .accept
                
            case "replace":
                // Clear the back stack after navigation for the appropriate navigator
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Determine which navigator to clear based on the URL and role
                    var navigator: Navigator?
                    
                    if self.currentRole == "client" {
                        if proposal.url.path.starts(with: "/meal_plans") {
                            navigator = self.dietaNavigator
                        } else if proposal.url.path.starts(with: "/compounds_plans") {
                            navigator = self.manipuladosNavigator
                        } else if proposal.url.path.starts(with: "/anthropometric_assessments") {
                            navigator = self.evolucaoNavigator
                        } else if proposal.url.path.starts(with: "/settings/") {
                            navigator = self.profileNavigator
                        } else {
                            navigator = self.treinoNavigator
                        }
                    } else if self.currentRole == "coach" {
                        if proposal.url.path.starts(with: "/clients") {
                            navigator = self.clientsNavigator
                        } else if proposal.url.path.starts(with: "/exercises") {
                            navigator = self.exercisesNavigator
                        } else if proposal.url.path.starts(with: "/settings/") {
                            navigator = self.coachProfileNavigator
                        }
                    }
                    
                    if let navController = navigator?.rootViewController as? UINavigationController,
                       navController.viewControllers.count > 1 {
                        if let lastVC = navController.viewControllers.last {
                            navController.setViewControllers([lastVC], animated: false)
                        }
                    }
                }
                return .accept
                
            default:
                return .accept
            }
        }
        
        // Accept all other proposals with default behavior
        return .accept
    }
    
    
    private func getCurrentVisitable() -> VisitableViewController? {
        var navigator: Navigator?

        if currentRole == "client" {
            if selectedIndex == 0 {
                navigator = treinoNavigator
            } else if selectedIndex == 1 {
                navigator = dietaNavigator
            } else if selectedIndex == 2 {
                navigator = manipuladosNavigator
            } else if selectedIndex == 3 {
                navigator = evolucaoNavigator
            } else if selectedIndex == 4 {
                navigator = profileNavigator
            }
        } else if currentRole == "coach" {
            if selectedIndex == 0 {
                navigator = clientsNavigator
            } else if selectedIndex == 1 {
                navigator = exercisesNavigator
            } else if selectedIndex == 2 {
                navigator = coachProfileNavigator
            }
        }
        
        return navigator?.rootViewController.visibleViewController as? VisitableViewController
    }
    
    func navigatorDidFinishNavigation(_ navigator: Navigator) {
        // Check if we've navigated to login page
        if let visitable = getCurrentVisitable(),
           visitable.currentVisitableURL.path == "/session/new" {
            // Trigger logout
            DispatchQueue.main.async {
                App.shared.performLogout()
            }
            return
        }

        // Check path configuration for hide_tab_bar property
        if let visitable = getCurrentVisitable() {
            let url = visitable.currentVisitableURL
            #if DEBUG
            print("TabBarController - navigatorDidFinishNavigation - Path: \(url.path)")
            #endif

            let properties = Hotwire.config.pathConfiguration.properties(for: url)
            if let hideTabBar = properties["hide_tab_bar"] as? Bool, hideTabBar {
                #if DEBUG
                print("TabBarController - Hiding tab bar due to hide_tab_bar property")
                #endif
                DispatchQueue.main.async {
                    self.tabBar.isHidden = true
                }
            }
        }

        // Navigation bar visibility is now handled by AppWebViewController
    }
    
    func visitableDidRender() {
        // Check if we've navigated to login page
        if let visitable = getCurrentVisitable() {
            if visitable.currentVisitableURL.path == "/session/new" {
                // Trigger logout immediately
                App.shared.performLogout()
                return
            }
        }
        
        // Check current URL after render for the active navigator
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var currentURL: URL?
            
            if currentRole == "client" {
                if selectedIndex == 0 {
                    // Treino tab
                    let navController = self.treinoNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 1 {
                    // Dieta tab
                    let navController = self.dietaNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 2 {
                    // Manipulados tab
                    let navController = self.manipuladosNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 3 {
                    // Evolucao tab
                    let navController = self.evolucaoNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 4 {
                    // Profile tab
                    let navController = self.profileNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                }
            } else if currentRole == "coach" {
                if selectedIndex == 0 {
                    // Clients tab
                    let navController = self.clientsNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 1 {
                    // Exercises tab
                    let navController = self.exercisesNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 2 {
                    // Profile tab
                    let navController = self.coachProfileNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                }
            }
            
            if let url = currentURL {
                self.currentURL = url

                // Check path configuration for hide_tab_bar property
                let properties = Hotwire.config.pathConfiguration.properties(for: url)
                if let hideTabBar = properties["hide_tab_bar"] as? Bool, hideTabBar {
                    #if DEBUG
                    print("TabBarController - visitableDidRender - Hiding tab bar for: \(url.path)")
                    #endif
                    self.tabBar.isHidden = true
                } else {
                    self.updateTabBarVisibility(for: url)
                }
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let tag = viewController.tabBarItem.tag
        
        // Handle dynamic tabs from server configuration
        guard tag < tabConfigurations.count else {
            return true
        }
        
        let tab = tabConfigurations[tag]
        let url = URL(string: "\(App.baseURL)\(tab.path)")!
        
        // Get the navigator for this tab
        if let navigator = navigatorForTabId(tab.id) {
            navigator.route(url)
            
            // Hide navigation bar for client tabs
            if currentRole == "client" {
                DispatchQueue.main.async {
                    navigator.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            }
        }
        return true
    }
    
    private func navigatorForTabId(_ tabId: String) -> Navigator? {
        switch tabId {
        case "clients":
            return clientsNavigator
        case "exercises":
            return exercisesNavigator
        case "profile":
            return currentRole == "coach" ? coachProfileNavigator : profileNavigator
        case "treino":
            return treinoNavigator
        case "dieta":
            return dietaNavigator
        case "manipulados":
            return manipuladosNavigator
        case "evolucao":
            return evolucaoNavigator
        default:
            return nil
        }
    }
}
