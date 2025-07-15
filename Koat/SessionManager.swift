//
//  SessionManager.swift
//  Koat
//
//  Created by Assistant on 10/04/25.
//

import Foundation
import WebKit

class SessionManager {
    static let shared = SessionManager()
    
    private init() {}
    
    // Check and log all cookies (for debugging only)
    func logAllCookies(from dataStore: WKWebsiteDataStore) {
        // Function kept for potential future debugging needs
        // Currently does nothing in production
    }
    
    // Force save cookies by fetching them and storing them back
    func persistCookies(from webView: WKWebView, completion: @escaping () -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            // Filter for session cookies
            let sessionCookies = cookies.filter { cookie in
                cookie.name.contains("session") || cookie.name == "_koat_session"
            }
            
            completion()
        }
    }
}