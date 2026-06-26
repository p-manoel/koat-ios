//
//  AppleSignInComponent.swift
//  Koat
//
//  Hotwire Native bridge component that connects the web login screen's "Sign in
//  with Apple" button to native Sign in with Apple. The native analog of
//  GoogleSignInComponent.
//
//  Web side (Rails, when koat_ios_app? and the :apple_login flag is on) renders
//  the Apple button under a `bridge--apple-sign-in` Stimulus controller that
//  cancels the default form submit and sends a "login" event. This component runs
//  the native sheet, exchanges the Apple identity token for a Koat handoff token,
//  and routes the web view to the single-use redemption endpoint to establish the
//  session.
//

import AuthenticationServices
import HotwireNative
import UIKit

final class AppleSignInComponent: BridgeComponent {
    override class var name: String { "apple-sign-in" }

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

        AppleAuth.signIn(presenting: presenter) { [weak self] result in
            switch result {
            case .success(let credential):
                self?.exchange(credential)
            case .failure(let error):
                // A user-cancelled sheet is normal; anything else is worth logging.
                // Either way the web button just needs to be re-enabled.
                if (error as? ASAuthorizationError)?.code != .canceled {
                    print("[AppleSignIn] sign-in failed: \(error)")
                }
                self?.finishOnWeb()
            }
        }
    }

    private func exchange(_ credential: AppleAuth.Credential) {
        AppleAuth.exchange(identityToken: credential.identityToken, nonce: credential.nonce) { [weak self] result in
            switch result {
            case .success(let handoffToken):
                self?.redeemSession(handoffToken: handoffToken)
            case .failure(let error):
                print("[AppleSignIn] token exchange failed: \(error)")
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
