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
    
    struct MessageData: Codable {
        let success: Bool
        let error: String?
    }
    
    override func onReceive(message: Message) {
        // Handle messages from JavaScript
        if message.event == "perform" {
            performAppleSignIn()
        }
    }
    
    private func performAppleSignIn() {
        guard let delegate = delegate,
              let viewController = delegate.destination as? UIViewController else { return }
        
        AppleSignInManager.shared.signIn(from: viewController) { [weak self] success, error in
            let messageData = MessageData(
                success: success,
                error: success ? nil : (error ?? "Unknown error")
            )
            self?.reply(to: "signInComplete", with: messageData)
        }
    }
}