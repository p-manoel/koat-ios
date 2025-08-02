//
//  RoleComponent.swift
//  Koat
//
//  Created by Assistant on 10/04/25.
//

import UIKit
import HotwireNative

final class RoleComponent: BridgeComponent {
    override class var name: String { "role" }
    
    override func onReceive(message: Message) {
        if message.event == "connect" {
            guard let data: MessageData = message.data() else {
                return
            }
            handleRoleUpdate(data: data)
        } else if message.event == "disconnect" {
            handleRoleDisconnect()
        }
    }
    
    private func handleRoleUpdate(data: MessageData) {
        
        // Store role information
        UserDefaults.standard.set(data.role, forKey: "userRole")
        UserDefaults.standard.set(data.userId, forKey: "userId")
        UserDefaults.standard.set(data.userName, forKey: "userName")
        
        // Notify app about role change
        NotificationCenter.default.post(
            name: .userRoleDidChange,
            object: nil,
            userInfo: ["role": data.role]
        )
        
        // Update tab bar configuration
        let tabBarController = App.shared.tabBarController
        DispatchQueue.main.async {
            tabBarController.updateForRole(data.role)
        }
        
        reply(to: "connect")
    }
    
    private func handleRoleDisconnect() {
        // Clear stored role
        UserDefaults.standard.removeObject(forKey: "userRole")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userName")
    }
}

// MARK: - Message Data

private extension RoleComponent {
    struct MessageData: Codable {
        let role: String
        let userId: String
        let userName: String
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let userRoleDidChange = Notification.Name("userRoleDidChange")
}