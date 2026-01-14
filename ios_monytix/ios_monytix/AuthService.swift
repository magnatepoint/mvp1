//
//  AuthService.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import Supabase
import AuthenticationServices

class AuthService {
    let supabase: SupabaseClient
    
    init() {
        // Initialize Supabase with default configuration
        // Note: The "Initial session emitted" warning is informational and can be safely ignored.
        // It indicates the SDK will change behavior in a future major release.
        // The app works correctly with the current behavior.
        guard let supabaseURL = URL(string: Config.supabaseUrl) else {
            fatalError("Invalid Supabase URL in configuration")
        }
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
    
    // Get current user
    func getCurrentUser() async -> User? {
        do {
            let session = try await supabase.auth.session
            return session.user
        } catch {
            return nil
        }
    }
    
    // Get current session
    func getCurrentSession() async -> Session? {
        try? await supabase.auth.session
    }
    
    // Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws -> Session {
        return try await supabase.auth.signIn(
            email: email,
            password: password
        )
    }
    
    // Sign up with email and password
    func signUpWithEmail(email: String, password: String) async throws -> Session {
        let result = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        // signUp returns AuthResponse which has an optional session
        guard let session = result.session else {
            throw AuthError.signUpFailed
        }
        return session
    }
    
    // Sign in with Google
    func signInWithGoogle() async throws -> Bool {
        guard let redirectURL = URL(string: "io.supabase.monytix://login-callback/") else {
            throw AuthError.invalidRedirectURL
        }
        
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: redirectURL
        )
        
        return true
    }
    
    // Handle OAuth callback URL
    func handleOAuthCallback(url: URL) async throws -> Session {
        // The Supabase SDK should automatically handle the callback
        // But we can also manually process it if needed
        return try await supabase.auth.session(from: url)
    }
    
    // Sign in with Apple using ID token
    func signInWithApple(idToken: String) async throws -> Session {
        return try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken
            )
        )
    }
    
    // Sign out
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    // Listen to auth state changes
    var authStateChanges: AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, _) in supabase.auth.authStateChanges {
                    continuation.yield(event)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}


// Auth errors
enum AuthError: LocalizedError {
    case signUpFailed
    case appleSignInFailed
    case invalidRedirectURL
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed:
            return "Registration failed"
        case .appleSignInFailed:
            return "Apple Sign In failed"
        case .invalidRedirectURL:
            return "Invalid redirect URL configuration"
        }
    }
}


