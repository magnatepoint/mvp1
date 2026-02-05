//
//  Config.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct Config {
    // Supabase configuration
    // For mobile and desktop apps, prefer using the publishable key (anon key)
    // You can get these from your Supabase project settings: Settings → API
    static let supabaseUrl = "https://vwagtikpxbhjrffolrqn.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3YWd0aWtweGJoanJmZm9scnFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3ODE0NDksImV4cCI6MjA3NDM1NzQ0OX0.cYevGkIj1HkjKv7iC14TgR7ItGF6YnXJi5Qw6ONYmcQ"
    
    // API base URL. Read from Info.plist "API_BASE_URL" for Dokploy/custom backend; default production.
    static var apiBaseUrl: String {
        (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        ?? "https://api.monytix.ai"
    }
    
    // Helper to get connection instructions
    static var connectionInstructions: String {
        """
        Backend: \(apiBaseUrl)
        To use a different backend (e.g. Dokploy), set API_BASE_URL in Info.plist.
        """
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

