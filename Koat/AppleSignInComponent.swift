//
//  AppleSignInComponent.swift
//  Koat
//
//  Created by Assistant on 17/08/2025.
//

import Foundation
import HotwireNative
import AuthenticationServices

final class AppleSignInComponent: BridgeComponent {
    override class var name: String { "apple-sign-in" }
    
    override func onReceive(message: Message) {
        let action = message.event // event is not optional in Message
        
        switch action {
        case "perform":
            performAppleSignIn()
        default:
            print("Unknown Apple Sign-In action: \(action)")
        }
    }
    
    private func performAppleSignIn() {
        guard let delegate = delegate,
              let viewController = delegate.destination as? UIViewController else { return }
        
        AppleSignInManager.shared.signIn(from: viewController) { [weak self] success, error in
            if success {
                // Reply to the web component that sign in was successful
                let successData: [String: Any] = ["success": true]
                self?.reply(to: "signInComplete", with: successData)
            } else {
                // Reply with error
                let errorData: [String: Any] = [
                    "success": false,
                    "error": error ?? "Unknown error"
                ]
                self?.reply(to: "signInComplete", with: errorData)
            }
        }
    }
}