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
        
        // Hide tab bar initially until we know the user is authenticated
        tabBar.isHidden = true
        
        // Create a temporary navigator for the initial load
        let startURL = URL(string: "\(App.baseURL)")!
        tempNavigator = Navigator(configuration: .init(name: "temp", startLocation: startURL))
        tempNavigator.delegate = self
        
        // Show the temporary navigator until we get role information
        viewControllers = [tempNavigator.rootViewController]
        
        // Start navigation
        tempNavigator.route(startURL)
        
        
        // Start checking for role information
        startCheckingForRole()
    }
    
    private func startCheckingForRole() {
        var attempts = 0
        let maxAttempts = 20 // 10 seconds total
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            attempts += 1
            
            // Try to get role from the page via the navigator's web view
            if let navController = self.tempNavigator?.rootViewController,
               let visitable = navController.visibleViewController as? VisitableViewController,
               let webView = visitable.visitableView.webView {
                
                webView.evaluateJavaScript("""
                    (function() {
                        // First check for meta tag
                        var roleMeta = document.querySelector('meta[name="user-role"]');
                        if (roleMeta && roleMeta.content) {
                            return { role: roleMeta.content, source: 'meta' };
                        }
                        
                        // Check for bridge role element
                        var roleElement = document.querySelector('[data-controller="bridge--role"]');
                        if (roleElement) {
                            var role = roleElement.getAttribute('data-role');
                            if (role) {
                                return { role: role, source: 'bridge' };
                            }
                        }
                        
                        return null;
                    })()
                """) { [weak self] result, error in
                    if let dict = result as? [String: String],
                       let role = dict["role"],
                       let _ = dict["source"] {
                        timer.invalidate()
                        self?.updateForRole(role)
                    }
                }
            }
            
            // Fallback after max attempts
            if attempts >= maxAttempts && self.currentRole == nil {
                timer.invalidate()
            }
        }
    }
    
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
        // List of authentication-related paths where tab bar should be hidden
        let authPaths = ["/session/new", "/registration/new", "/password/new", "/password/edit"]
        let shouldHideTabBar = authPaths.contains(url.path)
        
        if shouldHideTabBar {
            tabBar.isHidden = true
            // Hide navigation bar for all navigators
            hideAllNavigationBars()
        } else {
            tabBar.isHidden = false
            // Update navigation bar visibility based on navigation depth
            updateNavigationBarVisibility()
            
            // Update selected tab based on current URL
            updateSelectedTab(for: url)
        }
    }
    
    private func hideAllNavigationBars() {
        if currentRole == "client" {
            treinoNavigator?.rootViewController.setNavigationBarHidden(true, animated: false)
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
    
    private func updateNavigationBarVisibility() {
        if currentRole == "client" {
            // Hide nav bar if at root of navigator (only one view controller in stack)
            if let nav = treinoNavigator?.rootViewController {
                nav.setNavigationBarHidden(nav.viewControllers.count <= 1, animated: false)
                nav.navigationBar.prefersLargeTitles = false
            }
            if let nav = profileNavigator?.rootViewController {
                nav.setNavigationBarHidden(nav.viewControllers.count <= 1, animated: false)
                nav.navigationBar.prefersLargeTitles = false
            }
        } else if currentRole == "coach" {
            if let nav = clientsNavigator?.rootViewController {
                nav.setNavigationBarHidden(nav.viewControllers.count <= 1, animated: false)
                nav.navigationBar.prefersLargeTitles = false
            }
            if let nav = exercisesNavigator?.rootViewController {
                nav.setNavigationBarHidden(nav.viewControllers.count <= 1, animated: false)
                nav.navigationBar.prefersLargeTitles = false
            }
            if let nav = coachProfileNavigator?.rootViewController {
                nav.setNavigationBarHidden(nav.viewControllers.count <= 1, animated: false)
                nav.navigationBar.prefersLargeTitles = false
            }
        }
    }
    
    private func updateSelectedTab(for url: URL) {
        // Determine which tab should be selected based on the URL path
        if currentRole == "client" {
            if url.path.starts(with: "/settings/") {
                // Profile-related pages should select profile tab
                selectedIndex = 1
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
    
    func updateForRole(_ role: String) {
        
        // Always update the role, even if it seems the same
        // This ensures proper setup after logout/login
        
        currentRole = role
        
        // Store the new role
        UserDefaults.standard.set(role, forKey: "userRole")
        
        // Clear existing timer if switching roles
        if let timer = navigationTimer {
            timer.invalidate()
            navigationTimer = nil
        }
        
        // Clear existing navigators to ensure fresh state
        treinoNavigator = nil
        profileNavigator = nil
        clientsNavigator = nil
        exercisesNavigator = nil
        coachProfileNavigator = nil
        
        // Reconfigure tabs based on role
        switch role {
        case "coach":
            setupCoachTabs()
        case "client":
            setupClientTabs()
        default:
            tabBar.isHidden = true
            return
        }
        
        // Restart navigation monitoring
        startMonitoringNavigation()
        
        // Navigate to the appropriate home page based on role
        let urlToRoute: URL
        if role == "coach" {
            // Coaches should go to clients page
            urlToRoute = URL(string: "\(App.baseURL)/clients")!
        } else {
            // Clients go to home
            urlToRoute = URL(string: "\(App.baseURL)")!
        }
        
        
        // Navigate based on role
        if role == "client" {
            treinoNavigator?.route(urlToRoute)
        } else if role == "coach" {
            clientsNavigator?.route(urlToRoute)
        }
    }
    
    private func setupClientTabs() {
        // Keep existing setupTabs logic for clients
        setupTabs()
    }
    
    private func setupCoachTabs() {
        // Create navigator for clients tab
        let startURL = URL(string: "\(App.baseURL)")!
        clientsNavigator = Navigator(configuration: .init(name: "clients", startLocation: startURL))
        clientsNavigator.delegate = self
        
        // Create navigator for exercises tab
        exercisesNavigator = Navigator(configuration: .init(name: "exercises", startLocation: startURL))
        exercisesNavigator.delegate = self
        
        // Create navigator for profile tab
        coachProfileNavigator = Navigator(configuration: .init(name: "profile", startLocation: startURL))
        coachProfileNavigator.delegate = self
        
        // Set initial URL
        currentURL = startURL
        
        // Configure tab bar items
        let clientsTab = clientsNavigator.rootViewController
        clientsTab.tabBarItem = UITabBarItem(title: "Clientes", image: UIImage(systemName: "person.2"), tag: 0)
        
        let exercisesTab = exercisesNavigator.rootViewController
        exercisesTab.tabBarItem = UITabBarItem(title: "Exercícios", image: UIImage(systemName: "figure.strengthtraining.traditional"), tag: 1)
        
        let profileTab = coachProfileNavigator.rootViewController
        profileTab.tabBarItem = UITabBarItem(title: "Perfil", image: UIImage(systemName: "person.circle"), tag: 2)
        
        // Hide navigation bar initially
        clientsTab.setNavigationBarHidden(true, animated: false)
        exercisesTab.setNavigationBarHidden(true, animated: false)
        profileTab.setNavigationBarHidden(true, animated: false)
        
        // Set view controllers
        viewControllers = [clientsTab, exercisesTab, profileTab]
        
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
        
        // Start with clients tab selected
        selectedIndex = 0
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
                guard let self = self else { return }
                
                // Determine which navigator to clear based on the URL and role
                var navigator: Navigator?
                
                if self.currentRole == "client" {
                    navigator = proposal.url.path.starts(with: "/settings/") ? self.profileNavigator : self.treinoNavigator
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
        }
        
        // Accept all other proposals with default behavior
        return .accept
    }
    
    func visitableDidRender() {
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
                self.updateTabBarVisibility(for: url)
                self.currentURL = url
            }
            
            // Always update navigation bar visibility after render
            self.updateNavigationBarVisibility()
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if currentRole == "client" {
            // Check if this is the profile tab
            if viewController.tabBarItem.tag == 1 {
                // Navigate to profile page when profile tab is selected
                profileNavigator.route(URL(string: "\(App.baseURL)/settings/profile")!)
            }
        } else if currentRole == "coach" {
            // Handle coach tab navigation
            switch viewController.tabBarItem.tag {
            case 0:
                // Clients tab
                clientsNavigator.route(URL(string: "\(App.baseURL)/clients")!)
            case 1:
                // Exercises tab
                exercisesNavigator.route(URL(string: "\(App.baseURL)/exercises")!)
            case 2:
                // Profile tab
                coachProfileNavigator.route(URL(string: "\(App.baseURL)/settings/profile")!)
            default:
                break
            }
        }
        return true
    }
}