//
//  AppleAuth.swift
//  Koat
//
//  Thin wrapper around Sign in with Apple (AuthenticationServices). All
//  ASAuthorization usage lives here so the rest of the app — and the Hotwire
//  Native bridge component — talks to a small Koat-shaped surface. The native
//  analog of GoogleAuth.swift; the backend verifies the identity token at
//  POST /api/oauth/apple. Login-only: we send the identity token (+ nonce), not
//  an authorization code (see docs/adr/0005 in the Rails repo).
//

import AuthenticationServices
import CryptoKit
import UIKit

enum AppleAuth {
    /// What a successful native Sign in with Apple yields: the Apple identity
    /// token (an OIDC JWT) and the *raw* sign-in nonce. The backend hashes the
    /// raw nonce (SHA256 hex) and checks it against the token's `nonce` claim, so
    /// both values must be handed off together.
    struct Credential {
        let identityToken: String
        let nonce: String
    }

    /// Present the native Sign in with Apple sheet from `presenter` and hand back
    /// the identity token + raw nonce on success. That token is what the backend
    /// exchanges for a Koat session at POST /api/oauth/apple.
    static func signIn(presenting presenter: UIViewController,
                       completion: @escaping (Result<Credential, Swift.Error>) -> Void) {
        // The controller retains itself until a delegate callback fires.
        SignInController(presenter: presenter, completion: completion).start()
    }

    /// Exchange an Apple identity token for a single-use Koat handoff token via
    /// the backend (POST /api/oauth/apple). The handoff token is then redeemed in
    /// the web view to establish the session cookie. Mirrors
    /// GoogleAuth.exchangeIDToken; the completion is delivered on the main queue.
    static func exchange(identityToken: String, nonce: String,
                         completion: @escaping (Result<String, Swift.Error>) -> Void) {
        let endpoint = URL(string: "\(App.baseURL)/api/oauth/apple")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["identity_token": identityToken, "nonce": nonce]
        )

        URLSession.shared.dataTask(with: request) { data, response, error in
            func finish(_ result: Result<String, Swift.Error>) {
                DispatchQueue.main.async { completion(result) }
            }

            if let error {
                finish(.failure(error))
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let data else {
                finish(.failure(status == 409 ? Error.accountCollision
                                              : Error.exchangeFailed(status: status)))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(ExchangeResponse.self, from: data)
                if payload.success, let token = payload.handoffToken {
                    finish(.success(token))
                } else {
                    finish(.failure(Error.exchangeFailed(status: status)))
                }
            } catch {
                finish(.failure(error))
            }
        }.resume()
    }

    /// A cryptographically-random raw nonce as lowercase hex (32 bytes = 256 bits
    /// of entropy). The hashed form goes into the authorization request; the raw
    /// form is sent to the backend. Hex is URL/JSON-safe and bias-free — no
    /// mapping of bytes onto a character set whose size doesn't divide 256.
    static func randomNonce(byteCount: Int = 32) -> String {
        precondition(byteCount > 0)
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Lowercase SHA256 hex — must match Ruby's `Digest::SHA256.hexdigest` on the
    /// backend so the nonce round-trips (CONTEXT.md "Sign-in nonce").
    static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private struct ExchangeResponse: Decodable {
        let success: Bool
        let handoffToken: String?
    }

    enum Error: Swift.Error {
        case missingIdentityToken
        case accountCollision
        case exchangeFailed(status: Int)
    }
}

/// Drives a single ASAuthorizationController flow and bridges its delegate
/// callbacks to a completion handler. Holds a strong reference to itself for the
/// duration of the request (Apple always calls exactly one delegate method, so
/// the reference is always released).
private final class SignInController: NSObject,
                                      ASAuthorizationControllerDelegate,
                                      ASAuthorizationControllerPresentationContextProviding {
    private let presenter: UIViewController
    private let completion: (Result<AppleAuth.Credential, Swift.Error>) -> Void
    private let rawNonce: String
    private var selfRetain: SignInController?

    init(presenter: UIViewController,
         completion: @escaping (Result<AppleAuth.Credential, Swift.Error>) -> Void) {
        self.presenter = presenter
        self.completion = completion
        self.rawNonce = AppleAuth.randomNonce()
        super.init()
    }

    func start() {
        selfRetain = self

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleAuth.sha256Hex(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            deliver(.failure(AppleAuth.Error.missingIdentityToken))
            return
        }

        // credential.fullName is intentionally discarded: User has no name column,
        // and the name is collected at role selection (ADR-0005). Apple only sends
        // it on the first authorization anyway.
        deliver(.success(AppleAuth.Credential(identityToken: identityToken, nonce: rawNonce)))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Swift.Error) {
        deliver(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // The presenter is the on-screen Hotwire destination when the button is
        // tapped, so it normally has a window; fall back to the app's root window
        // rather than a detached one if it somehow doesn't.
        presenter.view.window ?? App.shared.rootViewController.view.window ?? ASPresentationAnchor()
    }

    /// Deliver the result on the main queue (matching AppleAuth.exchange and
    /// GoogleAuth) and release the self-retain last, so the object stays alive
    /// until the caller's completion has run.
    private func deliver(_ result: Result<AppleAuth.Credential, Swift.Error>) {
        DispatchQueue.main.async {
            self.completion(result)
            self.selfRetain = nil
        }
    }
}
