//
//  AuthManager.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var session: Session?
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    
    let authService: AuthService
    private var authStateTask: Task<Void, Never>?
    
    var isAuthenticated: Bool {
        user != nil
    }
    
    var userEmail: String? {
        user?.email
    }
    
    init(authService: AuthService) {
        self.authService = authService
        initialize()
    }
    
    convenience init() {
        let service = AuthService()
        self.init(authService: service)
    }
    
    private func initialize() {
        // Check for existing session
        Task {
            user = await authService.getCurrentUser()
            session = await authService.getCurrentSession()
            isLoading = false
            
            // Listen to auth state changes
            authStateTask = Task {
                for await event in authService.authStateChanges {
                    await handleAuthStateChange(event)
                }
            }
            
            // Listen for unauthorized errors (401) to trigger auto-logout
            NotificationCenter.default.addObserver(forName: .authUnauthorized, object: nil, queue: .main) { [weak self] _ in
                Task {
                    try? await self?.signOut()
                }
            }
        }
    }
    
    private func handleAuthStateChange(_ event: AuthChangeEvent) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed:
            user = await authService.getCurrentUser()
            session = await authService.getCurrentSession()
        case .signedOut:
            user = nil
            session = nil
        case .userUpdated:
            user = await authService.getCurrentUser()
        case .passwordRecovery:
            break
        default:
            break
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await authService.signInWithEmail(email: email, password: password)
            self.session = session
            self.user = session.user
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await authService.signUpWithEmail(email: email, password: password)
            self.session = session
            self.user = session.user
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.signInWithGoogle()
            // OAuth flow will complete via deep link, auth state listener will update session
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    func signInWithApple(idToken: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await authService.signInWithApple(idToken: idToken)
            self.session = session
            self.user = session.user
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func signOut() async throws {
        isLoading = true
        
        do {
            try await authService.signOut()
            user = nil
            session = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    deinit {
        authStateTask?.cancel()
    }
}

extension Notification.Name {
    static let authUnauthorized = Notification.Name("authUnauthorized")
}

