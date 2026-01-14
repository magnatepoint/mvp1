//
//  SpendSenseViewModel.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SpendSenseViewModel: ObservableObject {
    private let service: SpendSenseService
    
    // KPIs
    @Published var kpis: SpendSenseKPIs?
    @Published var isKPILoading = false
    @Published var availableMonths: [String] = []
    
    // Insights
    @Published var insights: Insights?
    @Published var isInsightsLoading = false
    
    // Transactions
    @Published var transactions: [Transaction] = []
    @Published var isTransactionsLoading = false
    @Published var totalCount = 0
    @Published var currentPage = 1
    
    // Filters
    @Published var searchText = ""
    @Published var selectedCategoryCode: String?
    @Published var selectedStartDate: Date?
    @Published var selectedEndDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    
    // File Upload
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadError: String?
    @Published var pdfPassword = ""
    
    // Error states
    @Published var kpiError: String?
    @Published var insightsError: String?
    @Published var transactionsError: String?
    
    init(authService: AuthService) {
        self.service = SpendSenseService(authService: authService)
        
        // Debounce search
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.reloadTransactions()
                }
            }
            .store(in: &cancellables)
    }
    
    func reloadTransactions() async {
        currentPage = 1
        await loadTransactions()
    }
    
    func loadKPIs(month: String? = nil) async {
        isKPILoading = true
        kpiError = nil
        defer { isKPILoading = false }
        
        do {
            kpis = try await service.getKPIs(month: month)
        } catch {
            kpiError = formatError(error)
            print("Error loading KPIs: \(error)")
        }
    }
    
    func loadAvailableMonths() async {
        do {
            availableMonths = try await service.getAvailableMonths()
        } catch {
            print("Error loading available months: \(error)")
        }
    }
    
    func loadInsights() async {
        isInsightsLoading = true
        insightsError = nil
        defer { isInsightsLoading = false }
        
        do {
            insights = try await service.getInsights()
        } catch {
            insightsError = formatError(error)
            print("Error loading insights: \(error)")
        }
    }
    
    func loadTransactions(limit: Int = 25, offset: Int? = nil) async {
        isTransactionsLoading = true
        transactionsError = nil
        defer { isTransactionsLoading = false }
        
        do {
            let actualOffset = offset ?? ((currentPage - 1) * 25)
            
            // Format dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startStr = selectedStartDate.map { dateFormatter.string(from: $0) }
            let endStr = selectedEndDate.map { dateFormatter.string(from: $0) }
            
            let response = try await service.getTransactions(
                limit: limit,
                offset: actualOffset,
                search: searchText,
                categoryCode: selectedCategoryCode,
                startDate: startStr,
                endDate: endStr
            )
            if offset == nil {
                // Normal pagination - replace transactions
                transactions = response.transactions
                totalCount = response.total
            } else {
                // Loading for subcategories - append to existing transactions (deduplicate by id)
                var existingIds = Set(transactions.map { $0.id })
                var updatedTransactions = transactions
                for transaction in response.transactions {
                    if !existingIds.contains(transaction.id) {
                        updatedTransactions.append(transaction)
                        existingIds.insert(transaction.id)
                    }
                }
                transactions = updatedTransactions
            }
        } catch {
            transactionsError = formatError(error)
            print("Error loading transactions: \(error)")
        }
    }
    
    func uploadFile(fileURL: URL) async {
        isUploading = true
        uploadProgress = 0
        uploadError = nil
        
        defer {
            isUploading = false
            uploadProgress = 0
        }
        
        do {
            _ = try await service.uploadFile(
                fileURL: fileURL,
                password: pdfPassword.isEmpty ? nil : pdfPassword,
                onProgress: { progress in
                    Task { @MainActor in
                        self.uploadProgress = progress * 100
                    }
                }
            )
            
            // Reset password
            pdfPassword = ""
            
            // Reload data
            await loadTransactions()
            await loadKPIs()
        } catch {
            uploadError = error.localizedDescription
        }
    }
    
    func nextPage() {
        let totalPages = max(1, (totalCount + 24) / 25)
        if currentPage < totalPages {
            currentPage += 1
            Task {
                await loadTransactions()
            }
        }
    }
    
    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            Task {
                await loadTransactions()
            }
        }
    }
    
    func getSubcategoryBreakdown(for categoryName: String) -> [SubcategoryBreakdown] {
        // Filter transactions by category
        let categoryTransactions = transactions.filter { transaction in
            transaction.displayCategory.lowercased() == categoryName.lowercased()
        }
        
        // Group by subcategory
        var subcategoryMap: [String: (amount: Double, count: Int)] = [:]
        var totalAmount: Double = 0
        
        for transaction in categoryTransactions {
            let subcategoryName = transaction.subcategory ?? transaction.subcategoryCode ?? "Uncategorized"
            let amount = abs(transaction.amount)
            
            if subcategoryMap[subcategoryName] == nil {
                subcategoryMap[subcategoryName] = (amount: 0, count: 0)
            }
            subcategoryMap[subcategoryName]?.amount += amount
            subcategoryMap[subcategoryName]?.count += 1
            totalAmount += amount
        }
        
        // Convert to SubcategoryBreakdown array
        var breakdown: [SubcategoryBreakdown] = []
        for (name, data) in subcategoryMap {
            let percentage = totalAmount > 0 ? (data.amount / totalAmount) * 100 : 0
            breakdown.append(SubcategoryBreakdown(
                subcategoryName: name,
                amount: data.amount,
                percentage: percentage,
                transactionCount: data.count
            ))
        }
        
        // Sort by amount descending
        return breakdown.sorted { $0.amount > $1.amount }
    }
    
    private func formatError(_ error: Error) -> String {
        let nsError = error as NSError
        
        // Connection errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Please check your network."
            case NSURLErrorCannotConnectToHost, NSURLErrorTimedOut:
                return "Cannot connect to server. Please ensure the backend is running on port 8001."
            case NSURLErrorCannotFindHost:
                return "Server not found. Please check the API URL configuration."
            default:
                return "Connection error: \(nsError.localizedDescription)"
            }
        }
        
        // HTTP errors
        if let spendSenseError = error as? SpendSenseError {
            if case .httpError(let statusCode, let message) = spendSenseError {
                if statusCode == 401 {
                    return "Authentication failed. Please sign in again."
                } else if statusCode == 404 {
                    return "Data not found. This is normal for new users."
                } else {
                    return "Server error (\(statusCode)): \(message)"
                }
            }
            return spendSenseError.localizedDescription
        }
        
        return error.localizedDescription
    }
}

