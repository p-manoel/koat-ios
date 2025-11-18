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
    
    func setupForRole(_ role: String, with navigator: Navigator) {
        self.currentRole = role
        
        // Store the role
        UserDefaults.standard.set(role, forKey: "userRole")
        
        // Set up tabs based on role
        switch role {
        case "coach":
            setupCoachTabs(with: navigator)
        case "client":
            setupClientTabs(with: navigator)
        default:
            return
        }
        
        // Show the tab bar
        tabBar.isHidden = false
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
                    // Dieta tab
                    let navController = self.dietaNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 2 {
                    // Evolucao tab
                    let navController = self.evolucaoNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 3 {
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
        // List of paths where tab bar should be hidden (auth and subscription pages)
        let authPaths = ["/session/new", "/registration/new", "/password/new", "/password/edit", "/subscriptions/select_plan"]
        let shouldHideTabBar = authPaths.contains(url.path)

        if shouldHideTabBar {
            tabBar.isHidden = true
            // Hide navigation bar for all navigators
            hideAllNavigationBars()
        } else {
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
                // Meal plan pages should select dieta tab
                selectedIndex = 1
            } else if url.path.starts(with: "/anthropometric_assessments") {
                // Anthropometric assessment pages should select evolucao tab
                selectedIndex = 2
            } else if url.path.starts(with: "/settings/") {
                // Profile-related pages should select profile tab
                selectedIndex = 3
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
    
    
    private func setupClientTabs(with navigator: Navigator) {

        // Create new navigators for each tab
        let treinoURL = URL(string: "\(App.baseURL)")!
        let dietaURL = URL(string: "\(App.baseURL)/meal_plans")!
        let evolucaoURL = URL(string: "\(App.baseURL)/anthropometric_assessments/comparison")!
        let profileURL = URL(string: "\(App.baseURL)/settings/profile")!

        // Create navigator for treino tab
        treinoNavigator = Navigator(configuration: .init(name: "treino", startLocation: treinoURL))
        treinoNavigator.delegate = self

        // Create navigator for dieta tab
        dietaNavigator = Navigator(configuration: .init(name: "dieta", startLocation: dietaURL))
        dietaNavigator.delegate = self

        // Create navigator for evolucao tab
        evolucaoNavigator = Navigator(configuration: .init(name: "evolucao", startLocation: evolucaoURL))
        evolucaoNavigator.delegate = self

        // Create navigator for profile tab
        profileNavigator = Navigator(configuration: .init(name: "profile", startLocation: profileURL))
        profileNavigator.delegate = self

        // Set initial URL
        currentURL = treinoURL

        // Configure tab bar items
        let treinoTab = treinoNavigator.rootViewController
        treinoTab.tabBarItem = UITabBarItem(title: "Treino", image: UIImage(systemName: "dumbbell"), tag: 0)

        let dietaTab = dietaNavigator.rootViewController
        dietaTab.tabBarItem = UITabBarItem(title: "Dieta", image: UIImage(systemName: "fork.knife"), tag: 1)

        let evolucaoTab = evolucaoNavigator.rootViewController
        evolucaoTab.tabBarItem = UITabBarItem(title: "Evolução", image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 2)

        let profileTab = profileNavigator.rootViewController
        profileTab.tabBarItem = UITabBarItem(title: "Perfil", image: UIImage(systemName: "person.circle"), tag: 3)

        // Don't hide navigation bar - let Hotwire Native handle it based on navigation depth
        // The navigation bar will be shown/hidden automatically when pushing/popping views

        // Set view controllers
        viewControllers = [treinoTab, dietaTab, evolucaoTab, profileTab]
        
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
        
        // Make tab bar visible now that tabs are configured
        tabBar.isHidden = false
        
        // Navigate to the initial URLs for each navigator
        treinoNavigator.route(treinoURL)
        dietaNavigator.route(dietaURL)
        evolucaoNavigator.route(evolucaoURL)
        profileNavigator.route(profileURL)

        // Ensure navigation bars are hidden for tabs that should not show them
        DispatchQueue.main.async {
            self.treinoNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
            self.dietaNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
            self.evolucaoNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
            self.profileNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
        }
    }
    
    private func setupCoachTabs(with navigator: Navigator) {
        
        // Create new navigators for each tab
        let clientsURL = URL(string: "\(App.baseURL)/clients")!
        let exercisesURL = URL(string: "\(App.baseURL)/exercises")!
        let profileURL = URL(string: "\(App.baseURL)/settings/profile")!
        
        // Create navigator for clients tab
        clientsNavigator = Navigator(configuration: .init(name: "clients", startLocation: clientsURL))
        clientsNavigator.delegate = self
        let clientsTab = clientsNavigator.rootViewController
        clientsTab.tabBarItem = UITabBarItem(title: "Clientes", image: UIImage(systemName: "person.2"), tag: 0)
        
        // Create navigator for exercises tab
        exercisesNavigator = Navigator(configuration: .init(name: "exercises", startLocation: exercisesURL))
        exercisesNavigator.delegate = self
        
        // Create navigator for profile tab
        coachProfileNavigator = Navigator(configuration: .init(name: "profile", startLocation: profileURL))
        coachProfileNavigator.delegate = self
        
        // Set TabBarController as delegate for ALL navigator instances to catch logout
        
        // Set initial URL
        currentURL = clientsURL
        
        // Configure tab bar items
        let exercisesTab = exercisesNavigator.rootViewController
        exercisesTab.tabBarItem = UITabBarItem(title: "Exercícios", image: UIImage(systemName: "figure.strengthtraining.traditional"), tag: 1)
        
        let profileTab = coachProfileNavigator.rootViewController
        profileTab.tabBarItem = UITabBarItem(title: "Perfil", image: UIImage(systemName: "person.circle"), tag: 2)
        
        // Don't hide navigation bar - let Hotwire Native handle it based on navigation depth
        // The navigation bar will be shown/hidden automatically when pushing/popping views
        
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
        
        // Make tab bar visible now that tabs are configured
        tabBar.isHidden = false
        
        // Navigate to the initial URLs for each navigator
        clientsNavigator.route(clientsURL)
        exercisesNavigator.route(exercisesURL)
        coachProfileNavigator.route(profileURL)
    }
    
    // This method is no longer needed since setupClientTabs handles everything
    // Keeping it for backwards compatibility if needed
    func setupTabs(with navigator: Navigator) {
        setupClientTabs(with: navigator)
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
                navigator = evolucaoNavigator
            } else if selectedIndex == 3 {
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
                    // Evolucao tab
                    let navController = self.evolucaoNavigator.rootViewController
                    if let visitable = navController.visibleViewController as? VisitableViewController {
                        currentURL = visitable.currentVisitableURL
                    }
                } else if selectedIndex == 3 {
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
                self.updateTabBarVisibility(for: url)
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if currentRole == "client" {
            // Handle client tab navigation
            switch viewController.tabBarItem.tag {
            case 0:
                // Treino tab
                treinoNavigator.route(URL(string: "\(App.baseURL)")!)
                // Ensure navigation bar is hidden
                DispatchQueue.main.async {
                    self.treinoNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            case 1:
                // Dieta tab
                dietaNavigator.route(URL(string: "\(App.baseURL)/meal_plans")!)
                // Ensure navigation bar is hidden
                DispatchQueue.main.async {
                    self.dietaNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            case 2:
                // Evolucao tab
                evolucaoNavigator.route(URL(string: "\(App.baseURL)/anthropometric_assessments/comparison")!)
                // Ensure navigation bar is hidden
                DispatchQueue.main.async {
                    self.evolucaoNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            case 3:
                // Profile tab
                profileNavigator.route(URL(string: "\(App.baseURL)/settings/profile")!)
                // Ensure navigation bar is hidden
                DispatchQueue.main.async {
                    self.profileNavigator.rootViewController.setNavigationBarHidden(true, animated: false)
                }
            default:
                break
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
