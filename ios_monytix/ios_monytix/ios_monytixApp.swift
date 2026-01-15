//
//  ios_monytixApp.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Supabase

@main
struct ios_monytixApp: App {
    @StateObject private var authManager = AuthManager()
    
    init() {
        // Initialize Supabase
        // The AuthService will handle initialization
    }
    
    var body: some Scene {
        WindowGroup {
            AuthWrapper()
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle OAuth deep links
                    handleOAuthCallback(url: url)
                }
        }
    }
    
    private func handleOAuthCallback(url: URL) {
        // Handle OAuth callback from Supabase
        Task { @MainActor in
            do {
                print("[OAuth] Received callback URL: \(url.absoluteString)")
                print("[OAuth] URL scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil")")
                
                // Check if this is a Supabase OAuth callback
                if url.scheme == "io.supabase.monytix" && url.host == "login-callback" {
                    let authService = AuthService()
                    
                    print("[OAuth] Processing callback with Supabase...")
                    
                    // Process the OAuth callback - this will exchange the code for a session
                    let session = try await authService.handleOAuthCallback(url: url)
                    
                    print("[OAuth] Session created successfully: \(session.user.id)")
                    
                    // The auth state listener in AuthManager will automatically pick up the session change
                    // No need to manually update - the listener will handle it
                } else {
                    print("[OAuth] URL does not match expected scheme/host. Expected: io.supabase.monytix://login-callback/")
                }
            } catch {
                print("[OAuth] Error handling callback: \(error.localizedDescription)")
                if let authError = error as? AuthError {
                    print("[OAuth] AuthError: \(authError.localizedDescription)")
                }
            }
        }
    }
}
