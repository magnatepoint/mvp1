//
//  BudgetViewModel.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class BudgetViewModel: ObservableObject {
    private let service: BudgetService
    
    // Recommendations
    @Published var recommendations: [BudgetRecommendation] = []
    @Published var isRecommendationsLoading = false
    @Published var recommendationsError: String?
    
    // Committed Budget
    @Published var committedBudget: CommittedBudget?
    @Published var isCommittedLoading = false
    @Published var committedError: String?
    
    // Variance
    @Published var variance: BudgetVariance?
    @Published var isVarianceLoading = false
    @Published var varianceError: String?
    
    // Commit Action
    @Published var isCommitting = false
    @Published var commitError: String?
    
    init(authService: AuthService) {
        self.service = BudgetService(authService: authService)
    }
    
    // MARK: - Recommendations
    
    func loadRecommendations(month: String? = nil) async {
        isRecommendationsLoading = true
        recommendationsError = nil
        defer { isRecommendationsLoading = false }
        
        do {
            recommendations = try await service.getRecommendations(month: month)
        } catch {
            recommendationsError = formatError(error)
            print("Error loading recommendations: \(error)")
        }
    }
    
    // MARK: - Committed Budget
    
    func loadCommittedBudget(month: String? = nil) async {
        isCommittedLoading = true
        committedError = nil
        defer { isCommittedLoading = false }
        
        do {
            committedBudget = try await service.getCommittedBudget(month: month)
        } catch {
            committedError = formatError(error)
            print("Error loading committed budget: \(error)")
        }
    }
    
    // MARK: - Commit
    
    func commitToPlan(planCode: String, month: String? = nil, goalAllocations: [String: Double]? = nil, notes: String? = nil) async -> Bool {
        isCommitting = true
        commitError = nil
        defer { isCommitting = false }
        
        do {
            committedBudget = try await service.commitBudget(
                planCode: planCode,
                month: month,
                goalAllocations: goalAllocations,
                notes: notes
            )
            
            // Reload recommendations to update UI
            await loadRecommendations(month: month)
            
            return true
        } catch {
            commitError = formatError(error)
            print("Error committing budget: \(error)")
            return false
        }
    }
    
    // MARK: - Variance
    
    func loadVariance(month: String? = nil) async {
        isVarianceLoading = true
        varianceError = nil
        defer { isVarianceLoading = false }
        
        do {
            variance = try await service.getVariance(month: month)
        } catch {
            varianceError = formatError(error)
            print("Error loading variance: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatError(_ error: Error) -> String {
        if let budgetError = error as? BudgetError {
            return budgetError.errorDescription ?? "Unknown error"
        }
        return error.localizedDescription
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

