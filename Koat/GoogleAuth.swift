//
//  GoogleAuth.swift
//  Koat
//
//  Thin wrapper around the GoogleSignIn SDK. All GIDSignIn usage lives here so
//  the rest of the app — and the upcoming Hotwire Native bridge component —
//  talks to a small Koat-shaped surface instead of the SDK directly.
//

import GoogleSignIn
import UIKit

enum GoogleAuth {
    // OAuth client for this iOS app (bundle id Koat.Koat).
    private static let iosClientID =
        "1084344976628-bkndptkj4e0aoeto7uk4c34kb3mp35oj.apps.googleusercontent.com"

    // Web/server OAuth client. Passing it as `serverClientID` adds it to the ID
    // token's audience so the Rails backend (POST /api/oauth/google, PR #772)
    // can verify tokens minted for the server.
    private static let serverClientID =
        "1084344976628-457igposb12thsldsefs059htlor09ef.apps.googleusercontent.com"

    /// Install the shared GIDSignIn configuration. Call once, at app launch.
    static func configure() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iosClientID,
            serverClientID: serverClientID
        )
    }

    /// Forward an OAuth callback URL to the SDK. Call from the scene's
    /// `openURLContexts`. Returns true if GIDSignIn consumed the URL.
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// Present the native Google sheet from `presenter` and hand back the Google
    /// ID token on success. That token is what the backend exchanges for a Koat
    /// session at POST /api/oauth/google.
    static func signIn(presenting presenter: UIViewController,
                       completion: @escaping (Result<String, Swift.Error>) -> Void) {
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let idToken = result?.user.idToken?.tokenString else {
                completion(.failure(Error.missingIDToken))
                return
            }
            completion(.success(idToken))
        }
    }

    enum Error: Swift.Error {
        case missingIDToken
    }
}
