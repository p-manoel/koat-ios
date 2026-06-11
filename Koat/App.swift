//
//  App.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import HotwireNative
import UIKit

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
    private var started = false
    private var pendingDeepLinkURL: URL?

    private(set) lazy var navigator: Navigator = {
        let navigator = Navigator(configuration: .init(name: "main", startLocation: rootURL))
        navigator.delegate = self
        return navigator
    }()

    var rootViewController: UIViewController { navigator.rootViewController }

    func start() {
        guard !started else { return }
        started = true
        navigator.route(rootURL)
        if let url = pendingDeepLinkURL {
            pendingDeepLinkURL = nil
            navigator.route(url)
        }
    }

    // MARK: - Deep links (push notification taps)

    func handleDeepLink(path: String) {
        let url = path.hasPrefix("http") ? URL(string: path)
                                         : URL(string: App.baseURL + path)
        guard let url else { return }
        DispatchQueue.main.async {
            if self.started {
                self.navigator.route(url)        // warm app: route immediately
            } else {
                self.pendingDeepLinkURL = url    // cold start: buffer until start()
            }
        }
    }
}

extension App: NavigatorDelegate {
    // Fires after Turbo form submissions with the URL of the page hosting the
    // form. A submission from the login/registration page means a fresh session
    // cookie, so (re-)register the push token. The manager no-ops if logged out.
    func formSubmissionDidFinish(at url: URL) {
        if url.path == "/session/new" || url.path == "/registration/new" {
            PushNotificationManager.shared.refreshTokenRegistration()
        }
    }
}
