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
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif

        Hotwire.config.defaultViewController = { url in
            AppWebViewController(url: url)
        }

        // All navigation stacks (main + modal) get a permanently hidden nav bar
        // with swipe-back re-enabled.
        Hotwire.config.defaultNavigationController = {
            ChromelessNavigationController()
        }

        // Shared process pool for cookie sharing between web views
        let processPool = WKProcessPool()

        Hotwire.config.makeCustomWebView = { configuration in
            // "Koat iOS" deliberately omits "Hotwire Native"/"Turbo Native" so
            // Rails' hotwire_native_app? / turbo_native_app? return false and the
            // app receives the full web chrome. The native library never reads
            // the UA; Turbo integration is driven by an injected user script.
            configuration.applicationNameForUserAgent = "Koat iOS"
            configuration.processPool = processPool
            configuration.websiteDataStore = .default()

            configuration.allowsInlineMediaPlayback = true
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.allowsPictureInPictureMediaPlayback = false
            configuration.preferences.isFraudulentWebsiteWarningEnabled = false
            configuration.allowsAirPlayForMediaPlayback = true

            // Rails serves the no-zoom viewport only to hotwire_native_app?
            // user agents, which this app deliberately is not, so unintended
            // pinch-zoom is blocked here instead.
            configuration.userContentController.addUserScript(viewportLockScript)

            // Taps on external links leave the app via the system instead of
            // Hotwire's in-app Safari sheet (see ExternalLinkHandler).
            configuration.userContentController.addUserScript(ExternalLinkHandler.tapInterceptorScript)
            configuration.userContentController.add(ExternalLinkHandler.shared, name: ExternalLinkHandler.messageName)

            let webView = WKWebView(frame: .zero, configuration: configuration)

            // Edge-to-edge: let web content extend behind the status bar and home
            // indicator. Rails handles safe areas via viewport-fit=cover + env().
            webView.scrollView.contentInsetAdjustmentBehavior = .never

            // Session claims navigationDelegate; uiDelegate is ours. Without it,
            // window.confirm (Turbo's data-turbo-confirm) silently returns false
            // and target="_blank" links do nothing.
            webView.uiDelegate = WebViewUIHandler.shared

            AuthFlowObserver.observe(webView)

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

// Appending to the served meta (instead of replacing it) keeps directives
// like viewport-fit=cover that the Rails layout relies on for safe areas.
private let viewportLockScript = WKUserScript(
    source: """
    (function() {
      var meta = document.querySelector('meta[name="viewport"]');
      if (!meta) {
        meta = document.createElement("meta");
        meta.name = "viewport";
        meta.content = "width=device-width, initial-scale=1, viewport-fit=cover";
        document.head.appendChild(meta);
      }
      var directives = meta.content.split(",").map(function(d) { return d.trim(); }).filter(function(d) {
        return d && d.indexOf("maximum-scale") !== 0 && d.indexOf("user-scalable") !== 0;
      });
      directives.push("maximum-scale=1.0", "user-scalable=no");
      meta.content = directives.join(", ");
    })();
    """,
    injectionTime: .atDocumentEnd,
    forMainFrameOnly: true
)

// Turbo form submissions are fetch + pushState and never reach the navigation
// delegate, so formSubmissionDidFinish alone misses Google OAuth logins.
// webView.url is KVO-compliant and changes on both full loads and pushState:
// leaving the auth flow means a fresh session cookie, so (re-)register the
// push token. The manager no-ops when logged out.
private enum AuthFlowObserver {
    private static var observations: [NSKeyValueObservation] = []

    static func observe(_ webView: WKWebView) {
        observations.append(webView.observe(\.url, options: [.old, .new]) { _, change in
            guard let oldPath = (change.oldValue ?? nil)?.path,
                  let newPath = (change.newValue ?? nil)?.path,
                  oldPath != newPath else { return }
            if isAuthFlowPath(oldPath) && !isAuthFlowPath(newPath) {
                PushNotificationManager.shared.refreshTokenRegistration()
            }
        })
    }

    // Login, registration, and the OAuth redirect chain (/auth/...).
    private static func isAuthFlowPath(_ path: String) -> Bool {
        path == "/session/new" || path == "/registration/new" || path.hasPrefix("/auth/")
    }
}
