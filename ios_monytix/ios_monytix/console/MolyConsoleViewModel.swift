//
//  MolyConsoleViewModel.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MolyConsoleViewModel: ObservableObject {
    private let spendSenseService: SpendSenseService
    private let authService: AuthService
    
    // Shared data cache to avoid duplicate API calls
    private var cachedKPIs: SpendSenseKPIs?
    private var cachedInsights: Insights?
    
    // Overview
    @Published var overviewSummary: OverviewSummary?
    @Published var isOverviewLoading = false
    @Published var overviewError: String?
    
    // Accounts
    @Published var accounts: [Account] = []
    @Published var isAccountsLoading = false
    @Published var accountsError: String?
    
    // Spending
    @Published var monthlySpending: Double = 0
    @Published var spendingByCategory: [CategorySpending] = []
    @Published var isSpendingLoading = false
    @Published var spendingError: String?
    
    // Goals
    @Published var goals: [Goal] = []
    @Published var isGoalsLoading = false
    @Published var goalsError: String?
    
    // AI Insights
    @Published var aiInsights: [AIInsight] = []
    @Published var isInsightsLoading = false
    @Published var insightsError: String?
    
    init(authService: AuthService) {
        self.authService = authService
        self.spendSenseService = SpendSenseService(authService: authService)
    }
    
    // MARK: - Overview
    
    func loadOverview() async {
        isOverviewLoading = true
        overviewError = nil
        defer { isOverviewLoading = false }
        
        do {
            let kpis = try await spendSenseService.getKPIs()
            _ = try await spendSenseService.getInsights()
            let totalBalance = kpis.assetsAmount ?? 0
            let thisMonthSpending = (kpis.needsAmount ?? 0) + (kpis.wantsAmount ?? 0)
            let savingsRate = kpis.calculateSavingsRate()
            // Use already-loaded goals/insights from parallel tasks (no duplicate fetch)
            let activeGoalsCount = goals.filter { $0.isActive }.count
            let latestInsight = aiInsights.first
            overviewSummary = OverviewSummary(
                totalBalance: totalBalance,
                thisMonthSpending: thisMonthSpending,
                savingsRate: savingsRate,
                activeGoalsCount: activeGoalsCount,
                latestInsight: latestInsight
            )
        } catch {
            overviewError = formatError(error)
            print("Error loading overview: \(error)")
        }
    }
    
    // MARK: - Accounts
    
    func loadAccounts() async {
        isAccountsLoading = true
        accountsError = nil
        defer { isAccountsLoading = false }
        
        do {
            // For now, create mock accounts based on KPIs
            // In production, this would come from a dedicated accounts API
            let kpis = try await loadKPIsIfNeeded()
            
            // Mock accounts - in production, fetch from accounts API
            var mockAccounts: [Account] = []
            
            if let assets = kpis.assetsAmount, assets > 0 {
                // Create a savings account
                mockAccounts.append(Account(
                    id: UUID(),
                    bankName: "SBI Bank",
                    accountType: .savings,
                    balance: assets * 0.5,
                    accountNumber: "****1234",
                    lastUpdated: Date()
                ))
                
                // Create an investment account
                mockAccounts.append(Account(
                    id: UUID(),
                    bankName: "Zerodha",
                    accountType: .investment,
                    balance: assets * 0.5,
                    accountNumber: nil,
                    lastUpdated: Date()
                ))
            }
            
            // Add checking account if we have spending data
            if let needs = kpis.needsAmount, needs > 0 {
                mockAccounts.append(Account(
                    id: UUID(),
                    bankName: "HDFC Bank",
                    accountType: .checking,
                    balance: (kpis.incomeAmount ?? 0) * 0.2,
                    accountNumber: "****5678",
                    lastUpdated: Date()
                ))
            }
            
            accounts = mockAccounts.isEmpty ? createDefaultMockAccounts() : mockAccounts
        } catch {
            accountsError = formatError(error)
            // Fallback to mock data
            accounts = createDefaultMockAccounts()
        }
    }
    
    private func createDefaultMockAccounts() -> [Account] {
        return [
            Account(
                id: UUID(),
                bankName: "HDFC Bank",
                accountType: .checking,
                balance: 854051,
                accountNumber: "****5678",
                lastUpdated: Date()
            ),
            Account(
                id: UUID(),
                bankName: "SBI Bank",
                accountType: .savings,
                balance: 1235076,
                accountNumber: "****1234",
                lastUpdated: Date()
            ),
            Account(
                id: UUID(),
                bankName: "Zerodha",
                accountType: .investment,
                balance: 2845000,
                accountNumber: nil,
                lastUpdated: Date()
            )
        ]
    }
    
    // MARK: - Spending
    
    func loadSpending() async {
        isSpendingLoading = true
        spendingError = nil
        defer { isSpendingLoading = false }
        
        do {
            let insights = try await loadInsightsIfNeeded()
            
            // Calculate monthly spending from category breakdown
            if let categoryBreakdown = insights.categoryBreakdown {
                monthlySpending = categoryBreakdown.reduce(0) { $0 + $1.amount }
                
                spendingByCategory = categoryBreakdown.map { category in
                    CategorySpending(
                        category: category.categoryName,
                        amount: category.amount,
                        percentage: category.percentage,
                        transactionCount: category.transactionCount
                    )
                }
            } else {
                // Fallback: use KPIs
                let kpis = try await loadKPIsIfNeeded()
                monthlySpending = (kpis.needsAmount ?? 0) + (kpis.wantsAmount ?? 0)
                spendingByCategory = []
            }
        } catch {
            spendingError = formatError(error)
            print("Error loading spending: \(error)")
        }
    }
    
    // MARK: - Goals
    
    func loadGoals() async {
        isGoalsLoading = true
        goalsError = nil
        defer { isGoalsLoading = false }
        
        // For now, use mock data
        // In production, this would fetch from a goals API endpoint
        goals = createMockGoals()
    }
    
    private func createMockGoals() -> [Goal] {
        return [
            Goal(
                id: UUID(),
                name: "Emergency Fund",
                targetAmount: 1000000,
                savedAmount: 850000,
                targetDate: nil,
                category: "Emergency",
                isActive: true
            ),
            Goal(
                id: UUID(),
                name: "Vacation Fund",
                targetAmount: 500000,
                savedAmount: 320000,
                targetDate: nil,
                category: "Travel",
                isActive: true
            )
        ]
    }
    
    // MARK: - AI Insights
    
    func loadAIInsights() async {
        isInsightsLoading = true
        insightsError = nil
        defer { isInsightsLoading = false }
        
        // For now, create mock insights based on available data
        // In production, this would fetch from an AI insights API
        var mockInsights: [AIInsight] = []
        
        do {
            // Load KPIs and Insights in parallel, reuse cached if available
            async let kpisTask = loadKPIsIfNeeded()
            async let insightsTask = loadInsightsIfNeeded()
            
            let kpis = try await kpisTask
            let insights = try await insightsTask
            
            // Create spending alert if needed
            if let topCategories = kpis.topCategories, !topCategories.isEmpty {
                let topCategory = topCategories[0]
                if let spendAmount = topCategory.spendAmount, spendAmount > 50000,
                   let categoryName = topCategory.categoryName {
                    mockInsights.append(AIInsight(
                        id: UUID(),
                        title: "Spending Alert",
                        message: "Your spending on \(categoryName.lowercased()) increased 15% this month. Consider setting a daily limit of ₹500.",
                        type: .spendingAlert,
                        priority: .medium,
                        createdAt: Date(),
                        category: categoryName
                    ))
                }
            }
            
            // Use already-loaded goals from parallel task (no duplicate fetch)
            if let goal = goals.first, goal.progress > 0.8 {
                mockInsights.append(AIInsight(
                    id: UUID(),
                    title: "Good News!",
                    message: "You're on track to reach your \(goal.name.lowercased()) goal by November.",
                    type: .goalProgress,
                    priority: .low,
                    createdAt: Date(),
                    category: nil
                ))
            }
            
            // Create budget tip
            if let categoryBreakdown = insights.categoryBreakdown {
                let foodCategory = categoryBreakdown.first { $0.categoryName.contains("Food") || $0.categoryName.contains("Dining") }
                if let food = foodCategory, food.percentage > 25 {
                    mockInsights.append(AIInsight(
                        id: UUID(),
                        title: "Budget Tip",
                        message: "You're spending \(String(format: "%.0f", food.percentage))% on \(food.categoryName.lowercased()). Consider meal planning to reduce costs.",
                        type: .budgetTip,
                        priority: .low,
                        createdAt: Date(),
                        category: food.categoryName
                    ))
                }
            }
            
            // Create investment recommendation
            if let assets = kpis.assetsAmount, assets > 1000000 {
                mockInsights.append(AIInsight(
                    id: UUID(),
                    title: "Investment Tip",
                    message: "Your investment portfolio shows strong growth. Consider increasing SIP contributions.",
                    type: .investmentRecommendation,
                    priority: .low,
                    createdAt: Date(),
                    category: nil
                ))
            }
        } catch {
            print("Error loading data for insights: \(error)")
        }
        
        // If no insights generated, add default ones
        if mockInsights.isEmpty {
            mockInsights = createDefaultMockInsights()
        }
        
        aiInsights = mockInsights
    }
    
    private func createDefaultMockInsights() -> [AIInsight] {
        return [
            AIInsight(
                id: UUID(),
                title: "Spending Alert",
                message: "Your spending on dining increased 15% this month. Consider setting a daily limit of ₹500.",
                type: .spendingAlert,
                priority: .medium,
                createdAt: Date(),
                category: "Food & Dining"
            ),
            AIInsight(
                id: UUID(),
                title: "Good News!",
                message: "You're on track to reach your emergency fund goal by November.",
                type: .goalProgress,
                priority: .low,
                createdAt: Date(),
                category: nil
            ),
            AIInsight(
                id: UUID(),
                title: "Budget Tip",
                message: "You're spending 27% on food. Consider meal planning to reduce costs.",
                type: .budgetTip,
                priority: .low,
                createdAt: Date(),
                category: "Food & Dining"
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func formatError(_ error: Error) -> String {
        if let spendSenseError = error as? SpendSenseError {
            return spendSenseError.errorDescription ?? "Unknown error"
        }
        return error.localizedDescription
    }
}

// MARK: - Category Spending

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int
}

