//
//  SceneDelegate.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = App.shared.rootViewController
        window?.overrideUserInterfaceStyle = .light
        window?.makeKeyAndVisible()

        for activity in connectionOptions.userActivities where activity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = activity.webpageURL { App.shared.handleCheckoutReturn(url) }
        }
        for context in connectionOptions.urlContexts { handleOpenURL(context.url) }
        App.shared.start()
    }

    // Google Sign-In returns through the app's reversed-client-id URL scheme;
    // hand those callbacks to the SDK.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts { handleOpenURL(context.url) }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        App.shared.handleCheckoutReturn(url)
    }

    private func handleOpenURL(_ url: URL) {
        if !App.shared.handleCheckoutReturn(url) { GoogleAuth.handle(url) }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Clear badge when app becomes active
        UNUserNotificationCenter.current().setBadgeCount(0)
        App.shared.webViewController.recoverIfNeeded()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        PushNotificationManager.shared.refreshTokenRegistration()
    }
}
