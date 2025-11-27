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
    
    // Store the tab bar controller - will be recreated for each session
    private var _tabBarController: TabBarController?
    
    var tabBarController: TabBarController {
        if let existing = _tabBarController {
            return existing
        }
        let controller = TabBarController(app: self)
        _tabBarController = controller
        return controller
    }
    
    /// Create a fresh TabBarController for a new session
    private func createNewTabBarController() -> TabBarController {
        _tabBarController?.clearNavigators()
        let controller = TabBarController(app: self)
        _tabBarController = controller
        return controller
    }
    
    var rootViewController: UIViewController {
        navigator.rootViewController
    }
    
    weak var sceneDelegate: SceneDelegate?
    
    /// Timer for periodic role checking
    private var roleCheckTimer: Timer?
    
    private init() {
        configureHotwire()
    }
    
    func start() {
        navigator.route(rootURL)
        startRoleCheckTimer()
    }
    
    /// Start periodic role checking - used when we're on the main navigator waiting for login
    private func startRoleCheckTimer() {
        roleCheckTimer?.invalidate()
        
        roleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.sceneDelegate?.window?.rootViewController is TabBarController {
                timer.invalidate()
                self.roleCheckTimer = nil
                return
            }
            
            self.checkForRoleAndSwitchIfNeeded()
        }
    }
    
    /// Stop the role check timer
    private func stopRoleCheckTimer() {
        roleCheckTimer?.invalidate()
        roleCheckTimer = nil
    }
    
    func verifySession() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let hasSessionCookie = cookies.contains { cookie in
                cookie.name == "session_id" || cookie.name == "_koat_session"
            }
            
            if hasSessionCookie {
                guard let verifyURL = URL(string: "\(App.baseURL)/") else { return }
                var request = URLRequest(url: verifyURL)
                request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                
                let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let httpResponse = response as? HTTPURLResponse {
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
        let config = Navigator.Configuration(name: "main", startLocation: rootURL)
        let nav = Navigator(configuration: config)
        nav.delegate = self
        return nav
    }()
    
    // MARK: - Configuration
    
    private func configureHotwire() {
        UINavigationBar.appearance().prefersLargeTitles = false
        UINavigationBar.appearance().tintColor = .systemBlue
        
        Hotwire.registerBridgeComponents([
            ButtonComponent.self,
            RoleComponent.self
        ])
    }
}

// MARK: - NavigatorDelegate

extension App: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        if proposal.url.path == "/session/new" {
            if sceneDelegate?.window?.rootViewController is TabBarController {
                performLogout()
                return .reject
            }

            DispatchQueue.main.async { [weak self] in
                self?.navigator.rootViewController.setNavigationBarHidden(true, animated: false)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkForRoleAndSwitchIfNeeded()
            }
        }

        return .accept
    }

    func visitableDidRender() {
        guard sceneDelegate?.window?.rootViewController == navigator.rootViewController else {
            return
        }
        
        if let visitable = navigator.rootViewController.visibleViewController as? VisitableViewController {
            if visitable.currentVisitableURL.path == "/session/new" {
                navigator.rootViewController.setNavigationBarHidden(true, animated: false)
                return
            }
        }
        
        checkForRoleAndSwitchIfNeeded()
    }
    
    func navigatorDidFinishNavigation(_ navigator: Navigator) {
        guard sceneDelegate?.window?.rootViewController == navigator.rootViewController else {
            return
        }
        
        checkForRoleAndSwitchIfNeeded()
    }
    
    private func checkForRoleAndSwitchIfNeeded() {
        guard sceneDelegate?.window?.rootViewController == navigator.rootViewController else {
            return
        }
        
        let navController = navigator.rootViewController
        guard let visitable = navController.visibleViewController as? VisitableViewController else {
            return
        }
        
        guard let webView = visitable.visitableView.webView else {
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
            if error != nil {
                return
            }
            
            if let role = result as? String, !role.isEmpty && role != "none" {
                self?.switchToTabBarController(with: role)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    if self?.sceneDelegate?.window?.rootViewController == self?.navigator.rootViewController {
                        self?.checkForRoleAndSwitchIfNeeded()
                    }
                }
            }
        }
    }
    
    private func switchToTabBarController(with role: String) {
        stopRoleCheckTimer()
        
        fetchTabConfiguration { [weak self] tabs in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let tabs = tabs, !tabs.isEmpty else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.switchToTabBarController(with: role)
                    }
                    return
                }
                
                let tabController = self.createNewTabBarController()
                tabController.setupWithConfiguration(tabs, role: role, with: self.navigator)
                self.sceneDelegate?.window?.rootViewController = tabController
                
                // Re-register push token after successful login
                PushNotificationManager.shared.refreshTokenRegistration()
                
                if let window = self.sceneDelegate?.window {
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                }
            }
        }
    }
    
    private func fetchTabConfiguration(completion: @escaping ([TabConfiguration]?) -> Void) {
        guard let url = URL(string: "\(App.baseURL)/hotwire/native/v1/ios/tab_configuration") else {
            completion(nil)
            return
        }
        
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }
                
                do {
                    let tabs = try JSONDecoder().decode([TabConfiguration].self, from: data)
                    completion(tabs)
                } catch {
                    completion(nil)
                }
            }.resume()
        }
    }
}

// MARK: - Deep Linking

extension App {
    /// Handle deep link from push notification
    func handleDeepLink(path: String) {
        // Construct full URL from path
        guard let url = URL(string: "\(App.baseURL)\(path)") else {
            print("[DeepLink] Invalid path: \(path)")
            return
        }
        
        print("[DeepLink] Navigating to: \(url)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If we have a TabBarController, navigate within it
            if let tabController = self.sceneDelegate?.window?.rootViewController as? TabBarController {
                tabController.navigateToURL(url)
            } else {
                // Otherwise use the main navigator
                self.navigator.route(url)
            }
        }
    }
}

// MARK: - Logout

extension App {
    func performLogout() {
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
            if let cookies = HTTPCookieStorage.shared.cookies {
                for cookie in cookies {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
            
            UserDefaults.standard.removeObject(forKey: "userRole")
            UserDefaults.standard.removeObject(forKey: "userId")
            UserDefaults.standard.removeObject(forKey: "userName")
            UserDefaults.standard.synchronize()
            
            DispatchQueue.main.async {
                self?.cleanupAfterLogout()
            }
        }
    }
    
    @objc private func handleRoleChange(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let role = userInfo["role"] as? String {
            if sceneDelegate?.window?.rootViewController == navigator.rootViewController {
                switchToTabBarController(with: role)
            }
        }
    }
    
    private func cleanupAfterLogout() {
        stopRoleCheckTimer()
        
        if let oldTabController = _tabBarController {
            oldTabController.currentRole = nil
            oldTabController.tabBar.isHidden = true
            oldTabController.viewControllers = []
            oldTabController.clearNavigators()
        }
        _tabBarController = nil
        
        let loginURL = URL(string: "\(App.baseURL)/session/new")!
        let config = Navigator.Configuration(name: "main", startLocation: loginURL)
        navigator = Navigator(configuration: config)
        navigator.delegate = self
        
        sceneDelegate?.window?.rootViewController = navigator.rootViewController
        
        if let window = sceneDelegate?.window {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
        
        navigator.route(loginURL)
        startRoleCheckTimer()
    }
}
