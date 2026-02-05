//
//  SpendSenseService.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import Supabase

class SpendSenseService {
    private let authService: AuthService
    private let baseURL: String
    private let urlSession: URLSession
    
    init(authService: AuthService) {
        self.authService = authService
        self.baseURL = Config.apiBaseUrl
        
        // Configure URLSession with shorter timeouts for faster failure
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0  // 15 seconds instead of 60
        configuration.timeoutIntervalForResource = 30.0  // 30 seconds for entire resource
        configuration.waitsForConnectivity = false  // Fail fast if offline
        self.urlSession = URLSession(configuration: configuration)
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
            throw SpendSenseError.invalidURL
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
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpendSenseError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: .authUnauthorized, object: nil)
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SpendSenseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            return data
        } catch let error as SpendSenseError {
            throw error
        } catch {
            // Wrap connection errors with helpful messages
            throw SpendSenseError.connectionError(underlyingError: error)
        }
    }
    
    // MARK: - API Methods
    
    func getKPIs(month: String? = nil) async throws -> SpendSenseKPIs {
        var endpoint = "/v1/spendsense/kpis"
        if let month = month {
            endpoint += "?month=\(month)"
        }
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        return try decoder.decode(SpendSenseKPIs.self, from: data)
    }
    
    func getAvailableMonths() async throws -> [String] {
        let data = try await makeRequest(endpoint: "/v1/spendsense/kpis/available-months")
        let decoder = JSONDecoder()
        let response = try decoder.decode([String: [String]].self, from: data)
        return response["data"] ?? []
    }
    
    func getInsights(startDate: String? = nil, endDate: String? = nil) async throws -> Insights {
        var endpoint = "/v1/spendsense/insights"
        var queryParams: [String] = []
        
        if let startDate = startDate {
            queryParams.append("start_date=\(startDate)")
        }
        if let endDate = endDate {
            queryParams.append("end_date=\(endDate)")
        }
        
        if !queryParams.isEmpty {
            endpoint += "?\(queryParams.joined(separator: "&"))"
        }
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        return try decoder.decode(Insights.self, from: data)
    }
    
    func getTransactions(
        limit: Int = 25,
        offset: Int = 0,
        search: String? = nil,
        categoryCode: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> TransactionResponse {
        var endpoint = "/v1/spendsense/transactions?limit=\(limit)&offset=\(offset)"
        
        if let search = search, !search.isEmpty {
            let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            endpoint += "&search=\(encodedSearch)"
        }
        if let categoryCode = categoryCode {
            endpoint += "&category_code=\(categoryCode)"
        }
        if let startDate = startDate {
            endpoint += "&start_date=\(startDate)"
        }
        if let endDate = endDate {
            endpoint += "&end_date=\(endDate)"
        }
        
        let data = try await makeRequest(endpoint: endpoint)
        let decoder = JSONDecoder()
        return try decoder.decode(TransactionResponse.self, from: data)
    }
    
    func uploadFile(
        fileURL: URL,
        password: String? = nil,
        onProgress: @escaping (Double) -> Void
    ) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/v1/spendsense/uploads/file") else {
            throw SpendSenseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add auth token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Access security-scoped resource
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw SpendSenseError.httpError(statusCode: 403, message: "Permission denied: Unable to access the selected file. Please try selecting the file again.")
        }
        defer {
            fileURL.stopAccessingSecurityScopedResource()
        }
        
        // Add file
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add password if provided
        if let password = password, !password.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"password\"\r\n\r\n".data(using: .utf8)!)
            body.append(password.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Simulate progress
        onProgress(0.0)
        
        let (data, response) = try await urlSession.upload(for: request, from: body)
        
        onProgress(1.0)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpendSenseError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SpendSenseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        if data.isEmpty {
            return ["status": "success"]
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        
        return ["status": "success"]
    }
}

// MARK: - Errors

enum SpendSenseError: LocalizedError {
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

