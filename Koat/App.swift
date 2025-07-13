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
        // Clear cookies and session
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                           modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            print("App: Cookies cleared, navigating to login")
            
            // Clear the navigation stack first
            if let navController = self?.tabBarController.treinoNavigator.rootViewController as? UINavigationController {
                navController.setViewControllers([], animated: false)
            }
            
            // Navigate to login page using the tab bar's navigator
            self?.tabBarController.treinoNavigator.route(URL(string: "\(App.baseURL)/session/new")!)
        }
    }
}