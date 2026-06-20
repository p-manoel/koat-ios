//
//  SceneDelegate.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = App.shared.rootViewController
        window?.overrideUserInterfaceStyle = .light
        window?.makeKeyAndVisible()

        App.shared.start()
    }

    // Google Sign-In returns through the app's reversed-client-id URL scheme;
    // hand those callbacks to the SDK.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        GoogleAuth.handle(url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Clear badge when app becomes active
        UIApplication.shared.applicationIconBadgeNumber = 0
        // Web-view recovery and background tracking are handled automatically
        // by Hotwire's AppLifecycleObserver as of 1.2.2.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        PushNotificationManager.shared.refreshTokenRegistration()
    }
}
