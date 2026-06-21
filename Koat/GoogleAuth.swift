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

    /// Exchange a Google ID token for a single-use Koat handoff token via the
    /// backend (POST /api/oauth/google, PR #772). The handoff token is then
    /// redeemed in the web view to establish the session cookie. The completion
    /// is delivered on the main queue.
    static func exchangeIDToken(_ idToken: String,
                                completion: @escaping (Result<String, Swift.Error>) -> Void) {
        let endpoint = URL(string: "\(App.baseURL)/api/oauth/google")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["id_token": idToken])

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

    private struct ExchangeResponse: Decodable {
        let success: Bool
        let handoffToken: String?
    }

    enum Error: Swift.Error {
        case missingIDToken
        case accountCollision
        case exchangeFailed(status: Int)
    }
}
