//
//  App.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import UIKit
import HotwireNative
import WebKit

final class App {
    static let shared = App()
    
    static let baseURL: String = {
        #if DEBUG
        return "http://app.localhost:3000"
        #else
        return "https://app.koat.io"
        #endif
    }()
    
    private let rootURL = URL(string: baseURL)!
    
    lazy var tabBarController = TabBarController(app: self)
    
    var rootViewController: UIViewController {
        // Return the navigator's root view controller directly
        // The TabBarController will be set up when a role is detected
        navigator.rootViewController
    }
    
    weak var sceneDelegate: SceneDelegate?
    
    private init() {
        // Configure Hotwire before creating navigator
        configureHotwire()
    }
    
    func start() {
        // Hide navigation bar initially (especially for login page)
        navigator.rootViewController.setNavigationBarHidden(true, animated: false)
        
        // Start navigation - the server will redirect to login if not authenticated
        navigator.route(rootURL)
        
        // Start monitoring for role after initial navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkForRoleAndSwitchIfNeeded()
        }
    }
    
    func verifySession() {
        // Check if we have a session cookie
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let hasSessionCookie = cookies.contains { cookie in
                cookie.name == "session_id" || cookie.name == "_koat_session"
            }
            
            if hasSessionCookie {
                // Make a simple request to check if session is still valid
                guard let verifyURL = URL(string: "\(App.baseURL)/") else { return }
                var request = URLRequest(url: verifyURL)
                request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                
                let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let httpResponse = response as? HTTPURLResponse {
                            // If we get redirected to login, the session is invalid
                            if httpResponse.statusCode == 302 || httpResponse.statusCode == 401 {
                                self?.performLogout()
                            }
                        }
                    }
                }.resume()
            }
        }
    }
    
    // MARK: - Navigation
    
    lazy var navigator: Navigator = {
        // Create and return the main navigator
        let config = Navigator.Configuration(name: "main", startLocation: rootURL)
        let nav = Navigator(configuration: config)
        nav.delegate = self
        return nav
    }()
    
    // MARK: - Configuration
    
    private func configureHotwire() {
        // Configure navigation bar appearance
        UINavigationBar.appearance().prefersLargeTitles = false
        UINavigationBar.appearance().tintColor = .systemBlue
        
        // Register bridge components
        Hotwire.registerBridgeComponents([
            ButtonComponent.self,
            RoleComponent.self
        ])
    }
}

// MARK: - NavigatorDelegate

extension App: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        // Check if navigating to login page while TabBarController is active
        if proposal.url.path == "/session/new" {
            // If TabBarController is the root, this is a logout scenario
            if sceneDelegate?.window?.rootViewController is TabBarController {
                performLogout()
                return .reject // Reject this proposal as performLogout will handle navigation
            }
            
            // Otherwise just hide navigation bar for login page
            DispatchQueue.main.async { [weak self] in
                self?.navigator.rootViewController.setNavigationBarHidden(true, animated: false)
            }
        } else {
            // For all non-login pages, check for role after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkForRoleAndSwitchIfNeeded()
            }
        }
        
        return .accept
    }
    
    func visitableDidRender() {
        // Only check for role if we're using the main navigator (not TabBarController)
        guard sceneDelegate?.window?.rootViewController == navigator.rootViewController else {
            return
        }
        
        // Check current URL and hide navigation bar for login page
        if let visitable = navigator.rootViewController.visibleViewController as? VisitableViewController {
            if visitable.currentVisitableURL.path == "/session/new" {
                navigator.rootViewController.setNavigationBarHidden(true, animated: false)
                return
            }
        }
        
        checkForRoleAndSwitchIfNeeded()
    }
    
    func navigatorDidFinishNavigation(_ navigator: Navigator) {
        // Only check for role if we're using the main navigator (not TabBarController)
        guard sceneDelegate?.window?.rootViewController == navigator.rootViewController else {
            return
        }
        
        checkForRoleAndSwitchIfNeeded()
    }
    
    private func checkForRoleAndSwitchIfNeeded() {
        // Don't check if we've already switched to tab bar
        guard sceneDelegate?.window?.rootViewController == navigator.rootViewController else {
            return
        }
        
        // Try to get role from the page
        let navController = navigator.rootViewController
        guard let visitable = navController.visibleViewController as? VisitableViewController else {
            return
        }
        
        // Wait for webView to be available
        guard let webView = visitable.visitableView.webView else {
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.checkForRoleAndSwitchIfNeeded()
            }
            return
        }
        
        webView.evaluateJavaScript("""
            (function() {
                var roleMeta = document.querySelector('meta[name="user-role"]');
                if (roleMeta && roleMeta.content) {
                    return roleMeta.content;
                }
                return null;
            })()
        """) { [weak self] result, error in
            if let error = error {
                return
            }
            
            if let role = result as? String, !role.isEmpty && role != "none" {
                self?.switchToTabBarController(with: role)
            } else {
                // Retry after a short delay if no role found yet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    // Only retry if we haven't switched yet
                    if self?.sceneDelegate?.window?.rootViewController == self?.navigator.rootViewController {
                        self?.checkForRoleAndSwitchIfNeeded()
                    }
                }
            }
        }
    }
    
    private func switchToTabBarController(with role: String) {
        // Set up the tab bar controller with the detected role
        // Pass the navigator but TabBarController will create its own navigators for each tab
        tabBarController.setupForRole(role, with: navigator)
        
        // Switch the root view controller
        sceneDelegate?.window?.rootViewController = tabBarController
        
        // Animate the transition
        if let window = sceneDelegate?.window {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }
}

// MARK: - Logout

extension App {
    func performLogout() {
        // Clear all website data including cookies
        let dataStore = WKWebsiteDataStore.default()
        let websiteDataTypes = Set([
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeDiskCache
        ])
        
        dataStore.removeData(ofTypes: websiteDataTypes,
                           modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            // Clear cookies from HTTPCookieStorage as well
            if let cookies = HTTPCookieStorage.shared.cookies {
                for cookie in cookies {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
            
            // Clear stored user role
            UserDefaults.standard.removeObject(forKey: "userRole")
            UserDefaults.standard.removeObject(forKey: "userId")
            UserDefaults.standard.removeObject(forKey: "userName")
            UserDefaults.standard.synchronize()
            
            // Perform cleanup and navigate to login
            DispatchQueue.main.async {
                self?.cleanupAfterLogout()
            }
        }
    }
    
    @objc private func handleRoleChange(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let role = userInfo["role"] as? String {
            // Check if we need to switch to tab bar
            if sceneDelegate?.window?.rootViewController == navigator.rootViewController {
                switchToTabBarController(with: role)
            }
        }
    }
    
    private func cleanupAfterLogout() {
        // Reset tab bar controller completely
        tabBarController.currentRole = nil
        tabBarController.tabBar.isHidden = true
        tabBarController.viewControllers = []
        // Clear all navigators
        tabBarController.clientsNavigator = nil
        tabBarController.exercisesNavigator = nil
        tabBarController.coachProfileNavigator = nil
        tabBarController.treinoNavigator = nil
        tabBarController.profileNavigator = nil
        
        // Create a new navigator for clean state pointing to login page
        let loginURL = URL(string: "\(App.baseURL)/session/new")!
        let config = Navigator.Configuration(name: "main", startLocation: loginURL)
        navigator = Navigator(configuration: config)
        navigator.delegate = self
        
        // Hide navigation bar for login page
        navigator.rootViewController.setNavigationBarHidden(true, animated: false)
        
        // Switch back to navigator as root
        sceneDelegate?.window?.rootViewController = navigator.rootViewController
        
        // Animate the transition
        if let window = sceneDelegate?.window {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
        
        // Navigate to login page
        navigator.route(loginURL)
    }
}