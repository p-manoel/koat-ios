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
    
    // Check and log all cookies
    func logAllCookies(from dataStore: WKWebsiteDataStore) {
        dataStore.httpCookieStore.getAllCookies { cookies in
            print("SessionManager: Total cookies: \(cookies.count)")
            for cookie in cookies {
                print("  Cookie: \(cookie.name) = \(cookie.value) | Domain: \(cookie.domain) | Path: \(cookie.path)")
            }
        }
    }
    
    // Force save cookies by fetching them and storing them back
    func persistCookies(from webView: WKWebView, completion: @escaping () -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            print("SessionManager: Persisting \(cookies.count) cookies")
            
            // Filter for session cookies
            let sessionCookies = cookies.filter { cookie in
                cookie.name.contains("session") || cookie.name == "_koat_session"
            }
            
            print("SessionManager: Found \(sessionCookies.count) session cookies")
            
            for cookie in sessionCookies {
                print("  Persisting cookie: \(cookie.name) for domain: \(cookie.domain)")
            }
            
            completion()
        }
    }
}