//
//  BudgetService.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import Supabase

class BudgetService {
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
            throw BudgetError.invalidURL
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
                throw BudgetError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw BudgetError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            return data
        } catch let error as BudgetError {
            throw error
        } catch {
            throw BudgetError.connectionError(underlyingError: error)
        }
    }
    
    // MARK: - API Methods
    
    func getRecommendations(month: String? = nil) async throws -> [BudgetRecommendation] {
        var endpoint = "/v1/budget/recommendations"
        if let month = month {
            endpoint += "?month=\(month)"
        }
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        let response = try decoder.decode(BudgetRecommendationsResponse.self, from: data)
        return response.recommendations
    }
    
    func commitBudget(planCode: String, month: String? = nil, goalAllocations: [String: Double]? = nil, notes: String? = nil) async throws -> CommittedBudget {
        let request = BudgetCommitRequest(
            planCode: planCode,
            month: month,
            goalAllocations: goalAllocations,
            notes: notes
        )
        
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)
        let data = try await makeRequest(endpoint: "/v1/budget/commit", method: "POST", body: body)
        let decoder = JSONDecoder()
        let response = try decoder.decode(BudgetCommitResponse.self, from: data)
        return response.budget
    }
    
    func getCommittedBudget(month: String? = nil) async throws -> CommittedBudget? {
        var endpoint = "/v1/budget/commit"
        if let month = month {
            endpoint += "?month=\(month)"
        }
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        let response = try decoder.decode(CommittedBudgetResponse.self, from: data)
        return response.budget
    }
    
    func getVariance(month: String? = nil) async throws -> BudgetVariance? {
        var endpoint = "/v1/budget/variance"
        if let month = month {
            endpoint += "?month=\(month)"
        }
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        let response = try decoder.decode(BudgetVarianceResponse.self, from: data)
        return response.aggregate
    }
}

// MARK: - Errors

enum BudgetError: LocalizedError {
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

