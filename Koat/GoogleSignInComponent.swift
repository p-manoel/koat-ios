//
//  GoogleSignInComponent.swift
//  Koat
//
//  Hotwire Native bridge component that connects the web login screen's Google
//  button to native Google sign-in.
//
//  Web side (Rails, when `koat_ios_app?`) renders the Google button under a
//  `bridge--google-sign-in` Stimulus controller that cancels the default form
//  submit and sends a "login" event. This component runs the native sheet,
//  exchanges the Google ID token for a Koat handoff token, and routes the web
//  view to the single-use redemption endpoint to establish the session.
//

import HotwireNative
import UIKit

final class GoogleSignInComponent: BridgeComponent {
    override class var name: String { "google-sign-in" }

    private enum Event: String {
        case login
    }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else { return }
        switch event {
        case .login:
            startSignIn()
        }
    }

    private func startSignIn() {
        guard let presenter = delegate?.destination as? UIViewController else { return }

        GoogleAuth.signIn(presenting: presenter) { [weak self] result in
            switch result {
            case .success(let idToken):
                self?.exchange(idToken: idToken)
            case .failure(let error):
                print("[GoogleSignIn] sign-in cancelled or failed: \(error)")
                self?.finishOnWeb()
            }
        }
    }

    private func exchange(idToken: String) {
        GoogleAuth.exchangeIDToken(idToken) { [weak self] result in
            switch result {
            case .success(let handoffToken):
                self?.redeemSession(handoffToken: handoffToken)
            case .failure(let error):
                print("[GoogleSignIn] token exchange failed: \(error)")
                self?.finishOnWeb()
            }
        }
    }

    /// Load the single-use redemption endpoint in the web view. The backend sets
    /// the Koat session cookie there and redirects to app root (existing user) or
    /// role selection (new user), replacing the login screen.
    private func redeemSession(handoffToken: String) {
        var components = URLComponents(string: "\(App.baseURL)/hotwire/native/session")
        components?.queryItems = [URLQueryItem(name: "token", value: handoffToken)]
        guard let url = components?.url else { return }
        App.shared.navigator.route(url, options: VisitOptions(action: .replace))
    }

    /// Reply to the web so its Stimulus controller can re-enable the button when
    /// the native flow ends without navigating (cancel or error).
    private func finishOnWeb() {
        reply(to: Event.login.rawValue)
    }
}
