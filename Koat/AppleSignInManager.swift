//
//  AppleSignInManager.swift
//  Koat
//
//  Created by Assistant on 17/08/2025.
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()
    
    private var currentNonce: String?
    private weak var presentingViewController: UIViewController?
    private var completion: ((Bool, String?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    func signIn(from viewController: UIViewController, completion: @escaping (Bool, String?) -> Void) {
        self.presentingViewController = viewController
        self.completion = completion
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - Private Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func sendToServer(userId: String, identityToken: Data, email: String?, givenName: String?, familyName: String?) {
        guard let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            completion?(false, "Failed to decode identity token")
            return
        }
        
        let url = URL(string: "\(App.baseURL)/api/oauth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any?] = [
            "user_id": userId,
            "identity_token": identityTokenString,
            "email": email,
            "given_name": givenName,
            "family_name": familyName
        ]
        
        // Remove nil values
        let filteredParameters = parameters.compactMapValues { $0 }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: filteredParameters)
        } catch {
            completion?(false, "Failed to encode request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.completion?(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse else {
                    self?.completion?(false, "Invalid response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let success = json["success"] as? Bool,
                           success {
                            
                            // Store user info if provided
                            if let user = json["user"] as? [String: Any] {
                                if let userId = user["id"] as? Int {
                                    UserDefaults.standard.set(userId, forKey: "userId")
                                }
                                if let userName = user["name"] as? String {
                                    UserDefaults.standard.set(userName, forKey: "userName")
                                }
                            }
                            
                            // Check if role selection is needed
                            let needsRoleSelection = json["needs_role_selection"] as? Bool ?? false
                            
                            if needsRoleSelection {
                                // Navigate to role selection
                                self?.navigateToRoleSelection()
                            } else {
                                // Successfully authenticated with existing role
                                self?.completion?(true, nil)
                            }
                        } else {
                            let errorMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                            self?.completion?(false, errorMessage ?? "Authentication failed")
                        }
                    } catch {
                        self?.completion?(false, "Failed to parse response")
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Authentication failed"
                    self?.completion?(false, errorMessage)
                }
            }
        }.resume()
    }
    
    private func navigateToRoleSelection() {
        // Navigate to role selection page
        if let tabBarController = App.shared.tabBarController,
           let tempNav = tabBarController.tempNavigator {
            tempNav.route(URL(string: "\(App.baseURL)/role_selection/new")!)
            completion?(true, nil)
        } else {
            completion?(false, "Failed to navigate to role selection")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            
            // Get user data (only available on first sign in)
            let userId = appleIDCredential.user
            let email = appleIDCredential.email
            let givenName = appleIDCredential.fullName?.givenName
            let familyName = appleIDCredential.fullName?.familyName
            
            // Get identity token
            guard let identityToken = appleIDCredential.identityToken else {
                completion?(false, "Unable to fetch identity token")
                return
            }
            
            // Send to server
            sendToServer(userId: userId, identityToken: identityToken, email: email, givenName: givenName, familyName: familyName)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error
        if let error = error as? ASAuthorizationError {
            switch error.code {
            case .canceled:
                completion?(false, "Sign in with Apple was canceled")
            case .failed:
                completion?(false, "Sign in with Apple failed")
            case .invalidResponse:
                completion?(false, "Invalid response from Apple")
            case .notHandled:
                completion?(false, "Sign in with Apple not handled")
            case .unknown:
                completion?(false, "Unknown error occurred")
            @unknown default:
                completion?(false, "An unexpected error occurred")
            }
        } else {
            completion?(false, error.localizedDescription)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return presentingViewController?.view.window ?? UIWindow()
    }
}