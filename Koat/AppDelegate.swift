//
//  AppDelegate.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import UIKit
import HotwireNative
import WebKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire
        configureHotwire()
        
        // Configure push notifications
        configureNotifications(application)
        
        return true
    }
    
    // MARK: - Push Notifications Configuration
    
    private func configureNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("[Push] Authorization error: \(error)")
                return
            }
            
            if granted {
                print("[Push] Permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("[Push] Permission denied")
            }
        }
    }
    
    // MARK: - Push Token Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(token)")
        PushNotificationManager.shared.registerToken(token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Clear the badge when user taps notification
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        // Check for URL in the notification data
        if let data = userInfo["data"] as? [String: Any],
           let urlString = data["url"] as? String {
            App.shared.handleDeepLink(path: urlString)
        } else if let urlString = userInfo["url"] as? String {
            App.shared.handleDeepLink(path: urlString)
        }
        
        completionHandler()
    }
    
    // MARK: - Hotwire Configuration
    
    private func configureHotwire() {
        // Enable debug logging in development
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif
        
        // Show done button on modals (for login dismissal)
        Hotwire.config.showDoneButtonOnModals = true
        
        // Use custom WebViewController class for navigation bar handling
        Hotwire.config.defaultViewController = { url in
            return AppWebViewController(url: url)
        }
        
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
            RoleComponent.self
        ])
        
        // Load path configuration
        loadPathConfiguration()
    }
    
    private func loadPathConfiguration() {
        let localConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json")!
        let remoteConfigURL = URL(string: "\(App.baseURL)/hotwire/native/v1/ios/path_configuration")!
        
        // Load with fallback - local file first, then server
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
