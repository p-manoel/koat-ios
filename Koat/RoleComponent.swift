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
        print("[RoleComponent] Received message event: \(message.event)")
        
        if message.event == "connect" {
            guard let data: MessageData = message.data() else {
                print("[RoleComponent] Failed to parse message data")
                return
            }
            print("[RoleComponent] Parsed role data: role=\(data.role), userId=\(data.userId), userName=\(data.userName)")
            handleRoleUpdate(data: data)
        } else if message.event == "disconnect" {
            print("[RoleComponent] Handling disconnect")
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
        
        // The App class will handle role detection and tab switching
        // through the NavigatorDelegate methods
        
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