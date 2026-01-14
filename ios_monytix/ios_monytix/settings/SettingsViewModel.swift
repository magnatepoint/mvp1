//
//  SettingsViewModel.swift
//  ios_monytix
//
//  Created by santosh on 10/01/26.
//

import Foundation
import Combine
import Supabase

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var userId: String?
    @Published var isDeleting = false
    @Published var deleteError: String?
    
    private let authService: AuthService
    private let baseURL: String
    
    init(authService: AuthService) {
        self.authService = authService
        self.baseURL = Config.apiBaseUrl
    }
    
    func loadUserInfo() async {
        if let user = await authService.getCurrentUser() {
            userId = user.id.uuidString
        }
    }
    
    func deleteAllData() async {
        isDeleting = true
        deleteError = nil
        
        do {
            guard let url = URL(string: "\(baseURL)/v1/spendsense/data") else {
                throw SettingsError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add auth token
            guard let session = try? await authService.supabase.auth.session else {
                throw SettingsError.notAuthenticated
            }
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SettingsError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SettingsError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // Success
            deleteError = nil
        } catch {
            deleteError = error.localizedDescription
        }
        
        isDeleting = false
    }
}

enum SettingsError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let statusCode, let message):
            return "Error \(statusCode): \(message)"
        }
    }
}

