//
//  PushNotificationManager.swift
//  Koat
//
//  Created by Push Notifications Implementation
//

import Foundation
import WebKit

class PushNotificationManager {
    static let shared = PushNotificationManager()
    
    private var deviceToken: String?
    private let deviceId: String
    
    private init() {
        // Generate or retrieve a persistent device ID
        if let existingId = UserDefaults.standard.string(forKey: "pushDeviceId") {
            deviceId = existingId
        } else {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: "pushDeviceId")
        }
    }
    
    func registerToken(_ token: String) {
        deviceToken = token
        sendTokenToServer()
    }
    
    /// Re-sends the token to the server (call after login)
    func refreshTokenRegistration() {
        if deviceToken != nil {
            sendTokenToServer()
        }
    }
    
    func sendTokenToServer() {
        guard let token = deviceToken else {
            print("[Push] No token to send")
            return
        }
        
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            // Check if user is logged in (has session cookie)
            let hasSession = cookies.contains { cookie in
                cookie.name == "session_id" || cookie.name == "_koat_session"
            }
            
            guard hasSession else {
                print("[Push] No session cookie found, skipping token registration")
                return
            }
            
            guard let url = URL(string: "\(App.baseURL)/api/v1/push_subscriptions") else {
                print("[Push] Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            
            let body = Self.registrationPayload(
                token: token,
                deviceId: self.deviceId,
                timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
            )
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                print("[Push] Failed to serialize body: \(error)")
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[Push] Token registration failed: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("[Push] Token registered successfully")
                    } else {
                        print("[Push] Token registration failed with status: \(httpResponse.statusCode)")
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            print("[Push] Response: \(responseBody)")
                        }
                    }
                }
            }.resume()
        }
    }

    static func registrationPayload(
        token: String,
        deviceId: String,
        timeZoneIdentifier: String
    ) -> [String: Any] {
        [
            "push_subscription": [
                "platform": "ios",
                "device_token": token,
                "device_id": deviceId,
                "time_zone": timeZoneIdentifier
            ]
        ]
    }
    
    /// Unsubscribes this device from push notifications
    func unsubscribe() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            guard let url = URL(string: "\(App.baseURL)/api/v1/push_subscriptions/unsubscribe_device?device_id=\(self.deviceId)") else {
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("[Push] Unsubscribe failed: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("[Push] Unsubscribed successfully")
                }
            }.resume()
        }
    }
}
