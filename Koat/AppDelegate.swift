//
//  AppDelegate.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import UIKit
import HotwireNative
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire
        configureHotwire()
        return true
    }
    
    private func configureHotwire() {
        // Enable debug logging in development
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif
        
        // Show done button on modals (for login dismissal)
        Hotwire.config.showDoneButtonOnModals = true
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Configure title appearance
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().prefersLargeTitles = false
        
        // Set up shared process pool for cookie sharing between web views
        let processPool = WKProcessPool()
        
        // Configure web view
        Hotwire.config.makeCustomWebView = { configuration in
            configuration.applicationNameForUserAgent = "Koat iOS (Hotwire Native)"
            configuration.processPool = processPool
            // Use the default persistent data store
            configuration.websiteDataStore = .default()
            
            // Configure video playback behavior
            configuration.allowsInlineMediaPlayback = true
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.allowsPictureInPictureMediaPlayback = false
            
            // Configure preferences for better video performance
            // JavaScript is enabled by default in WKWebView
            configuration.preferences.isFraudulentWebsiteWarningEnabled = false
            
            // Allow air play for videos
            configuration.allowsAirPlayForMediaPlayback = true
            
            let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
            
            #if DEBUG
            // Enable web inspector for debugging
            if webView.responds(to: Selector(("isInspectable"))) {
                webView.perform(Selector(("setInspectable:")), with: true)
            }
            #endif
            
            return webView
        }
        
        // Register bridge components
        Hotwire.registerBridgeComponents([
            ButtonComponent.self,
            RoleComponent.self,
            AppleSignInComponent.self
        ])
        
        // Load path configuration
        loadPathConfiguration()
    }
    
    private func loadPathConfiguration() {
        let localConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json")!
        let remoteConfigURL = URL(string: "\(App.baseURL)/hotwire/native/v1/ios/path_configuration")!
        
        // Load with fallback
        Hotwire.loadPathConfiguration(from: [
            .file(localConfigURL),
            .server(remoteConfigURL)
        ])
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

