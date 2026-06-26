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
        guard let presenter = delegate?.destination as? UIViewController else {
            // No destination to present from: re-enable the web button rather than
            // leaving it stuck disabled after its `login` event.
            finishOnWeb()
            return
        }

        AppleAuth.signIn(presenting: presenter) { [weak self] result in
            switch result {
            case .success(let credential):
                self?.exchange(credential)
            case .failure:
                // A user-cancelled sheet is normal; anything else is worth logging
                // in debug. Either way the web button just needs to be re-enabled.
                #if DEBUG
                if case .failure(let error) = result,
                   (error as? ASAuthorizationError)?.code != .canceled {
                    print("[AppleSignIn] sign-in failed: \(error)")
                }
                #endif
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
                // A 409 means this email already belongs to a Koat account created
                // another way (Google, or Apple Hide-My-Email). Surface it to the web
                // so the page can show a message; other failures just re-enable.
                if let apple = error as? AppleAuth.Error, case .accountCollision = apple {
                    self?.finishOnWeb(error: "account_collision")
                } else {
                    #if DEBUG
                    print("[AppleSignIn] token exchange failed: \(error)")
                    #endif
                    self?.finishOnWeb()
                }
            }
        }
    }

    /// Load the single-use redemption endpoint in the web view. The backend sets
    /// the Koat session cookie there and redirects to app root (existing user) or
    /// role selection (new user), replacing the login screen.
    private func redeemSession(handoffToken: String) {
        var components = URLComponents(string: "\(App.baseURL)/hotwire/native/session")
        // Percent-encode the token but NOT `+`: URLComponents.queryItems leaves `+`
        // literal in the query, and Rack decodes a literal `+` to a space, corrupting
        // the single-use token so redemption misses and login silently dies. Encoding
        // `+` as %2B makes it round-trip. No-op if the backend already mints url-safe
        // tokens.
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+"))
        components?.percentEncodedQueryItems = [
            URLQueryItem(name: "token", value: handoffToken.addingPercentEncoding(withAllowedCharacters: allowed))
        ]
        guard let url = components?.url else {
            // Couldn't build the redemption URL after a successful auth + exchange;
            // re-enable the web button rather than leaving it stuck disabled.
            finishOnWeb()
            return
        }
        App.shared.navigator.route(url, options: VisitOptions(action: .replace))
    }

    /// Reply to the web so its Stimulus controller can re-enable the button when the
    /// native flow ends without navigating (cancel or error). When `error` is set,
    /// the reply carries it (jsonData `{"error": ...}`) so the web can show a message
    /// (e.g. an account collision); the bare form just re-enables the button.
    private func finishOnWeb(error: String? = nil) {
        if let error {
            reply(to: Event.login.rawValue, with: LoginReply(error: error))
        } else {
            reply(to: Event.login.rawValue)
        }
    }

    private struct LoginReply: Encodable {
        let error: String
    }
}
