//
//  GoalsService.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import Supabase

class GoalsService {
    private let authService: AuthService
    private let baseURL: String
    
    init(authService: AuthService) {
        self.authService = authService
        self.baseURL = Config.apiBaseUrl
    }
    
    // MARK: - Helper Methods
    
    private func getAuthToken() async -> String? {
        guard let session = try? await authService.supabase.auth.session else {
            return nil
        }
        return session.accessToken
    }
    
    private func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw GoalsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GoalsError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GoalsError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            return data
        } catch let error as GoalsError {
            throw error
        } catch {
            throw GoalsError.connectionError(underlyingError: error)
        }
    }
    
    // MARK: - API Methods
    
    func getCatalog() async throws -> [GoalCatalogItem] {
        let data = try await makeRequest(endpoint: "/v1/goals/catalog")
        let decoder = JSONDecoder()
        return try decoder.decode([GoalCatalogItem].self, from: data)
    }
    
    func getRecommendedGoals() async throws -> [GoalCatalogItem] {
        let data = try await makeRequest(endpoint: "/v1/goals/recommended")
        let decoder = JSONDecoder()
        return try decoder.decode([GoalCatalogItem].self, from: data)
    }
    
    func getGoals() async throws -> [GoalResponse] {
        let data = try await makeRequest(endpoint: "/v1/goals")
        let decoder = JSONDecoder()
        return try decoder.decode([GoalResponse].self, from: data)
    }
    
    func getGoal(goalId: UUID) async throws -> GoalResponse {
        let data = try await makeRequest(endpoint: "/v1/goals/\(goalId.uuidString)")
        let decoder = JSONDecoder()
        return try decoder.decode(GoalResponse.self, from: data)
    }
    
    func getProgress() async throws -> GoalsProgressResponse {
        let data = try await makeRequest(endpoint: "/v1/goals/progress")
        let decoder = JSONDecoder()
        return try decoder.decode(GoalsProgressResponse.self, from: data)
    }
    
    func getLifeContext() async throws -> LifeContext? {
        do {
            let data = try await makeRequest(endpoint: "/v1/goals/context")
            let decoder = JSONDecoder()
            return try decoder.decode(LifeContext.self, from: data)
        } catch GoalsError.httpError(let statusCode, _) where statusCode == 404 {
            return nil // No context exists yet
        } catch {
            throw error
        }
    }
    
    func updateLifeContext(_ context: LifeContext) async throws {
        let encoder = JSONEncoder()
        let body = try encoder.encode(context)
        _ = try await makeRequest(endpoint: "/v1/goals/context", method: "PUT", body: body)
    }
    
    func submitGoals(context: LifeContext, selectedGoals: [SelectedGoal]) async throws -> GoalsSubmitResponse {
        let request = GoalsSubmitRequest(context: context, selectedGoals: selectedGoals)
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)
        let data = try await makeRequest(endpoint: "/v1/goals/submit", method: "POST", body: body)
        let decoder = JSONDecoder()
        return try decoder.decode(GoalsSubmitResponse.self, from: data)
    }
    
    func updateGoal(goalId: UUID, estimatedCost: Double?, targetDate: Date?, currentSavings: Double?, importance: Int?, notes: String?) async throws -> GoalResponse {
        struct UpdateRequest: Codable {
            let estimatedCost: Double?
            let targetDate: String?
            let currentSavings: Double?
            let importance: Int?
            let notes: String?
            
            enum CodingKeys: String, CodingKey {
                case estimatedCost = "estimated_cost"
                case targetDate = "target_date"
                case currentSavings = "current_savings"
                case importance
                case notes
            }
        }
        
        let formatter = ISO8601DateFormatter()
        let dateString = targetDate.map { formatter.string(from: $0) }
        
        let updateRequest = UpdateRequest(
            estimatedCost: estimatedCost,
            targetDate: dateString,
            currentSavings: currentSavings,
            importance: importance,
            notes: notes
        )
        
        let encoder = JSONEncoder()
        let body = try encoder.encode(updateRequest)
        let data = try await makeRequest(endpoint: "/v1/goals/\(goalId.uuidString)", method: "PUT", body: body)
        let decoder = JSONDecoder()
        return try decoder.decode(GoalResponse.self, from: data)
    }
}

// MARK: - Errors

enum GoalsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError
    case connectionError(underlyingError: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .connectionError(let underlyingError):
            let nsError = underlyingError as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost {
                return """
                Could not connect to backend server.
                
                \(Config.connectionInstructions)
                
                Error: \(underlyingError.localizedDescription)
                """
            }
            return "Connection error: \(underlyingError.localizedDescription)"
        }
    }
}

