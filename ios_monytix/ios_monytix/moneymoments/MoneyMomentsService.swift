//
//  MoneyMomentsService.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import Supabase

enum MoneyMomentsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case connectionError(underlyingError: Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .connectionError(let error):
            return "Connection error: \(error.localizedDescription)\n\n\(Config.connectionInstructions)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

class MoneyMomentsService {
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
        let fullURLString = "\(baseURL)\(endpoint)"
        print("[MoneyMoments] makeRequest: \(method) \(fullURLString)")
        
        guard let url = URL(string: fullURLString) else {
            print("[MoneyMoments] ERROR: Invalid URL: \(fullURLString)")
            throw MoneyMomentsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // Add timeout
        
        // Add auth token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("[MoneyMoments] Auth token added (length: \(token.count))")
        } else {
            print("[MoneyMoments] WARNING: No auth token available!")
        }
        
        if let body = body {
            request.httpBody = body
            print("[MoneyMoments] Request body: \(body.count) bytes")
        }
        
        print("[MoneyMoments] Sending request to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("[MoneyMoments] Response received: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[MoneyMoments] ERROR: Invalid response type")
                throw MoneyMomentsError.invalidResponse
            }
            
            print("[MoneyMoments] HTTP Status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[MoneyMoments] ERROR: HTTP \(httpResponse.statusCode): \(errorMessage)")
                throw MoneyMomentsError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            print("[MoneyMoments] Request successful")
            return data
        } catch let error as MoneyMomentsError {
            print("[MoneyMoments] MoneyMomentsError thrown: \(error.localizedDescription)")
            throw error
        } catch let urlError as URLError {
            print("[MoneyMoments] URLError: code=\(urlError.code.rawValue), description=\(urlError.localizedDescription)")
            throw MoneyMomentsError.connectionError(underlyingError: urlError)
        } catch {
            print("[MoneyMoments] Unknown error: \(error)")
            // Wrap connection errors with helpful messages
            throw MoneyMomentsError.connectionError(underlyingError: error)
        }
    }
    
    // MARK: - API Methods
    
    func getMoments(month: String? = nil, allMonths: Bool = false) async throws -> [MoneyMoment] {
        var endpoint = "/v1/moneymoments/moments"
        var queryParams: [String] = []
        
        if let month = month {
            queryParams.append("month=\(month)")
        }
        
        if allMonths {
            queryParams.append("all_months=true")
        }
        
        if !queryParams.isEmpty {
            endpoint += "?" + queryParams.joined(separator: "&")
        }
        
        print("[MoneyMoments] API Request: GET \(baseURL)\(endpoint)")
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        let response = try decoder.decode(MoneyMomentsResponse.self, from: data)
        print("[MoneyMoments] API Response: \(response.moments.count) moments")
        return response.moments
    }
    
    func computeMoments(targetMonth: String? = nil) async throws -> ComputeMomentsResponse {
        var endpoint = "/v1/moneymoments/moments/compute"
        if let targetMonth = targetMonth {
            endpoint += "?target_month=\(targetMonth)"
        }
        
        let fullURL = "\(baseURL)\(endpoint)"
        print("[MoneyMoments] ===== COMPUTE MOMENTS REQUEST =====")
        print("[MoneyMoments] Full URL: \(fullURL)")
        print("[MoneyMoments] Method: POST")
        print("[MoneyMoments] Target Month: \(targetMonth ?? "nil")")
        
        do {
            let data = try await makeRequest(endpoint: endpoint, method: "POST")
            print("[MoneyMoments] Request completed, received \(data.count) bytes")
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(ComputeMomentsResponse.self, from: data)
            print("[MoneyMoments] ===== COMPUTE RESPONSE DECODED =====")
            print("[MoneyMoments] API Response: status=\(response.status), count=\(response.count), message=\(response.message ?? "none")")
            print("[MoneyMoments] Moments in response: \(response.moments.count)")
            return response
        } catch {
            print("[MoneyMoments] ===== ERROR IN computeMoments SERVICE =====")
            print("[MoneyMoments] Error type: \(type(of: error))")
            print("[MoneyMoments] Error: \(error)")
            throw error
        }
    }
    
    func getNudges(limit: Int = 20) async throws -> [Nudge] {
        let endpoint = "/v1/moneymoments/nudges?limit=\(limit)"
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        let response = try decoder.decode(NudgesResponse.self, from: data)
        return response.nudges
    }
    
    func logNudgeInteraction(
        deliveryId: String,
        eventType: String,
        metadata: [String: Any]? = nil
    ) async throws -> NudgeInteractionResponse {
        let endpoint = "/v1/moneymoments/nudges/\(deliveryId)/interact"
        
        var bodyDict: [String: Any] = ["event_type": eventType]
        if let metadata = metadata {
            bodyDict["metadata"] = metadata
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        
        let data = try await makeRequest(endpoint: endpoint, method: "POST", body: bodyData)
        let decoder = JSONDecoder()
        return try decoder.decode(NudgeInteractionResponse.self, from: data)
    }
    
    func evaluateNudges(asOfDate: String? = nil) async throws -> EvaluateNudgesResponse {
        var endpoint = "/v1/moneymoments/nudges/evaluate"
        if let asOfDate = asOfDate {
            endpoint += "?as_of_date=\(asOfDate)"
        }
        
        let data = try await makeRequest(endpoint: endpoint, method: "POST")
        let decoder = JSONDecoder()
        return try decoder.decode(EvaluateNudgesResponse.self, from: data)
    }
    
    func processNudges(limit: Int = 10) async throws -> ProcessNudgesResponse {
        let endpoint = "/v1/moneymoments/nudges/process?limit=\(limit)"
        
        let data = try await makeRequest(endpoint: endpoint, method: "POST")
        let decoder = JSONDecoder()
        return try decoder.decode(ProcessNudgesResponse.self, from: data)
    }
    
    func computeSignal(asOfDate: String? = nil) async throws -> ComputeSignalResponse {
        var endpoint = "/v1/moneymoments/signals/compute"
        if let asOfDate = asOfDate {
            endpoint += "?as_of_date=\(asOfDate)"
        }
        
        let data = try await makeRequest(endpoint: endpoint, method: "POST")
        let decoder = JSONDecoder()
        return try decoder.decode(ComputeSignalResponse.self, from: data)
    }
    
    func diagnose() async throws -> [String: Any] {
        let endpoint = "/v1/moneymoments/moments/diagnose"
        
        print("[MoneyMoments] API Request: GET \(baseURL)\(endpoint)")
        let data = try await makeRequest(endpoint: endpoint)
        
        // Parse JSON response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("[MoneyMoments] Diagnostic result: \(json)")
            return json
        }
        throw MoneyMomentsError.invalidResponse
    }
}

