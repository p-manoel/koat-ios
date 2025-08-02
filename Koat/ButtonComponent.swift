//
//  ButtonComponent.swift
//  Koat
//
//  Created by Pedro Manoel on 10/04/25.
//

import UIKit
import HotwireNative
import WebKit

final class ButtonComponent: BridgeComponent {
    override class var name: String { "button" }
    
    override func onReceive(message: Message) {
        guard let viewController = delegate?.destination as? UIViewController else { return }
        
        if message.event == "connect" {
            guard let data: MessageData = message.data() else { return }
            handleConnect(data: data, viewController: viewController)
        } else if message.event == "disconnect" {
            handleDisconnect(viewController: viewController)
        }
    }
    
    private func handleConnect(data: MessageData, viewController: UIViewController) {
        let button = UIBarButtonItem(
            title: data.title,
            style: .plain,
            target: self,
            action: #selector(performAction(_:))
        )
        button.accessibilityIdentifier = data.action
        
        if data.position == "left" {
            viewController.navigationItem.leftBarButtonItem = button
        } else {
            viewController.navigationItem.rightBarButtonItem = button
        }
        
        reply(to: "connect")
    }
    
    private func handleDisconnect(viewController: UIViewController) {
        viewController.navigationItem.rightBarButtonItem = nil
        viewController.navigationItem.leftBarButtonItem = nil
    }
    
    @objc private func performAction(_ sender: UIBarButtonItem) {
        guard let action = sender.accessibilityIdentifier else { return }
        
        switch action {
        case "logout":
            performLogout()
        case "refresh":
            App.shared.navigator.activeWebView.reload()
        default:
            // Send action back to web for custom handling
            reply(to: "tap", with: MessageData(title: "", action: action, position: ""))
        }
    }
    
    private func performLogout() {
        // Clear stored role first
        UserDefaults.standard.removeObject(forKey: "userRole")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userName")
        
        // Clear cookies and session
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                           modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            // Navigate to login
            self?.reply(to: "logout")
            App.shared.navigator.route(URL(string: "\(App.baseURL)/session/new")!)
        }
    }
}

// MARK: - Message Data

private extension ButtonComponent {
    struct MessageData: Codable {
        let title: String
        let action: String
        let position: String
    }
}