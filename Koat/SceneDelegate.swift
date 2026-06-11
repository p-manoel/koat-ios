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

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Clear badge when app becomes active
        UIApplication.shared.applicationIconBadgeNumber = 0
        // Recover web views whose content process was terminated in background
        App.shared.navigator.appDidBecomeActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        App.shared.navigator.appDidEnterBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        PushNotificationManager.shared.refreshTokenRegistration()
    }
}
