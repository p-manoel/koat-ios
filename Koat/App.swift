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
        tabBarController
    }
    
    weak var sceneDelegate: SceneDelegate?
    
    private init() {
        // Configure Hotwire before creating navigator
        configureHotwire()
    }
    
    func start() {
        // Start navigation - the server will redirect to login if not authenticated
        // Navigation will happen automatically through the tempNavigator in TabBarController
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
        let navigator = Navigator(configuration: .init(name: "main", startLocation: rootURL))
        navigator.delegate = self
        return navigator
    }()
    
    // MARK: - Configuration
    
    private func configureHotwire() {
        // Configure navigation bar appearance
        UINavigationBar.appearance().prefersLargeTitles = false
        UINavigationBar.appearance().tintColor = .systemBlue
    }
}

// MARK: - NavigatorDelegate

extension App: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> ProposalResult {
        // Forward to TabBarController's navigator delegate
        return .accept
    }
    
    func performLogout() {
        // First, make the logout request to the server
        guard let logoutURL = URL(string: "\(App.baseURL)/session") else { return }
        
        var request = URLRequest(url: logoutURL)
        request.httpMethod = "DELETE"
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        // Get cookies to send with request
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { cookies in
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    // Clear all website data including cookies
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
                        
                        // Reset tab bar controller
                        self?.tabBarController.currentRole = nil
                        
                        // Hide tabs until new role is determined
                        self?.tabBarController.tabBar.isHidden = true
                        
                        // Navigate to login page using temp navigator
                        if let tempNav = self?.tabBarController.tempNavigator {
                            tempNav.route(URL(string: "\(App.baseURL)/session/new")!)
                        } else if let treinoNav = self?.tabBarController.treinoNavigator {
                            treinoNav.route(URL(string: "\(App.baseURL)/session/new")!)
                        }
                    }
                }
            }.resume()
        }
    }
}