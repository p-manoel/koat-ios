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
        // Simply start navigation
        tabBarController.treinoNavigator.route(URL(string: "\(App.baseURL)")!)
    }
    
    func verifySession() {
        // Check if we have a session cookie
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let hasSessionCookie = cookies.contains { cookie in
                cookie.name == "session_id" || cookie.name == "_koat_session"
            }
            
            if hasSessionCookie {
                print("App: Session cookie found, verifying with server")
                
                // Make a simple request to check if session is still valid
                guard let verifyURL = URL(string: "\(App.baseURL)/") else { return }
                var request = URLRequest(url: verifyURL)
                request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                
                let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let httpResponse = response as? HTTPURLResponse {
                            print("App: Session verification response: \(httpResponse.statusCode)")
                            
                            // If we get redirected to login, the session is invalid
                            if httpResponse.statusCode == 302 || httpResponse.statusCode == 401 {
                                print("App: Session invalid, performing logout")
                                self?.performLogout()
                            }
                        }
                    }
                }.resume()
            } else {
                print("App: No session cookie found")
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
        print("App: performLogout called")
        
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
                    print("App: Logout request completed")
                    
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
                        print("App: All website data cleared")
                        
                        // Clear cookies from HTTPCookieStorage as well
                        if let cookies = HTTPCookieStorage.shared.cookies {
                            for cookie in cookies {
                                HTTPCookieStorage.shared.deleteCookie(cookie)
                            }
                        }
                        
                        // Clear the navigation stack
                        if let navController = self?.tabBarController.treinoNavigator.rootViewController as? UINavigationController {
                            navController.setViewControllers([], animated: false)
                        }
                        
                        // Navigate to login page
                        self?.tabBarController.treinoNavigator.route(URL(string: "\(App.baseURL)/session/new")!)
                    }
                }
            }.resume()
        }
    }
}