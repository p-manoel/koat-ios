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

    /// Every Hotwire Native bridge component the app provides. Single source of
    /// truth: registered at launch *and* advertised in the user agent, so the
    /// web @hotwired/hotwire-native-bridge knows which components are supported.
    private static let bridgeComponents: [BridgeComponent.Type] = [
        GoogleSignInComponent.self,
        AppleSignInComponent.self
    ]

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire
        configureHotwire()

        // Configure Google Sign-In (installs the shared GIDSignIn client config)
        GoogleAuth.configure()
        
        // Configure push notifications
        configureNotifications(application)
        observeSystemTimeZoneChanges()
        
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

    private func observeSystemTimeZoneChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemTimeZoneDidChange),
            name: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
    }

    @objc private func systemTimeZoneDidChange() {
        PushNotificationManager.shared.refreshTokenRegistration()
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
        center.setBadgeCount(0)
        
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
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif

        // Bridge components let the web drive native features.
        Hotwire.registerBridgeComponents(Self.bridgeComponents)

        Hotwire.config.defaultViewController = { url in
            AppWebViewController(url: url)
        }

        // All navigation stacks (main + modal) get a permanently hidden nav bar
        // with swipe-back re-enabled.
        Hotwire.config.defaultNavigationController = {
            ChromelessNavigationController()
        }

        // The web bridge discovers supported components by reading this list out
        // of navigator.userAgent (see UA comment below).
        let bridgeComponentNames = Self.bridgeComponents.map { $0.name }.joined(separator: " ")
        let userAgent = "Koat iOS; bridge-components: [\(bridgeComponentNames)]"

        Hotwire.config.makeCustomWebView = { configuration in
            // "Koat iOS" deliberately omits "Hotwire Native"/"Turbo Native" so
            // Rails' hotwire_native_app? / turbo_native_app? return false and the
            // app receives the full web chrome. The native library never reads
            // the UA; Turbo integration is driven by an injected user script.
            //
            // The "bridge-components: [...]" suffix is how the web
            // @hotwired/hotwire-native-bridge learns which components this app
            // supports and enables the matching Stimulus controller. It contains
            // neither "Hotwire Native" nor "Turbo Native", so the chrome/viewport
            // gating is unaffected. Hotwire normally appends this itself, but we
            // replace the whole UA here, so we include it explicitly.
            configuration.applicationNameForUserAgent = userAgent
            // Shared default data store handles cookie sharing across web views
            // (process pools no longer have any effect as of iOS 15).
            configuration.websiteDataStore = .default()

            configuration.allowsInlineMediaPlayback = true
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.allowsPictureInPictureMediaPlayback = false
            configuration.preferences.isFraudulentWebsiteWarningEnabled = false
            configuration.allowsAirPlayForMediaPlayback = true

            let webView = WKWebView(frame: .zero, configuration: configuration)

            // Edge-to-edge: let web content extend behind the status bar and home
            // indicator. Rails handles safe areas via viewport-fit=cover + env().
            webView.scrollView.contentInsetAdjustmentBehavior = .never

            #if DEBUG
            webView.isInspectable = true
            #endif

            return webView
        }

        // Local file only: a stale/forgotten server endpoint must not be able to
        // re-introduce native modals or nav bars. To re-enable remote config later,
        // append .server(URL(string: "\(App.baseURL)/hotwire/native/v1/ios/path_configuration")!).
        let localConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json")!
        Hotwire.loadPathConfiguration(from: [.file(localConfigURL)])
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
