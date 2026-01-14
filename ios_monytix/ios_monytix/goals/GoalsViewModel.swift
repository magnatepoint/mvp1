//
//  GoalsViewModel.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class GoalsViewModel: ObservableObject {
    private let service: GoalsService
    
    // Catalog and Recommendations
    @Published var catalog: [GoalCatalogItem] = []
    @Published var recommendedGoals: [GoalCatalogItem] = []
    @Published var isCatalogLoading = false
    @Published var catalogError: String?
    
    // User Goals
    @Published var userGoals: [GoalResponse] = []
    @Published var isGoalsLoading = false
    @Published var goalsError: String?
    
    // Progress
    @Published var progress: [GoalProgress] = []
    @Published var isProgressLoading = false
    @Published var progressError: String?
    
    // Life Context
    @Published var lifeContext: LifeContext?
    @Published var isContextLoading = false
    @Published var contextError: String?
    
    // Stepper State
    @Published var currentStep: Int = 1
    @Published var selectedGoals: [SelectedGoal] = []
    @Published var currentGoalIndex: Int = 0
    @Published var isSubmitting = false
    @Published var submitError: String?
    
    // AI Insights
    @Published var aiInsights: [AIInsight] = []
    @Published var isAIInsightsLoading = false
    @Published var aiInsightsError: String?
    
    init(authService: AuthService) {
        self.service = GoalsService(authService: authService)
    }
    
    // MARK: - Computed Properties (Metrics)
    
    var activeGoalsCount: Int {
        userGoals.filter { $0.status.lowercased() == "active" }.count
    }
    
    var completedGoalsCount: Int {
        userGoals.filter { $0.status.lowercased() == "completed" }.count
    }
    
    var totalProgressPercentage: Double {
        guard !progress.isEmpty else { return 0 }
        let totalProgress = progress.reduce(0.0) { $0 + $1.progressPct }
        return totalProgress / Double(progress.count)
    }
    
    var goalAchieverLevel: String {
        let completionRate = userGoals.isEmpty ? 0 : Double(completedGoalsCount) / Double(userGoals.count) * 100
        let avgProgress = totalProgressPercentage
        
        if completionRate >= 80 && avgProgress >= 80 {
            return "Expert"
        } else if completionRate >= 60 && avgProgress >= 60 {
            return "Advanced"
        } else if completionRate >= 40 && avgProgress >= 40 {
            return "Intermediate"
        } else {
            return "Beginner"
        }
    }
    
    var activeGoals: [GoalResponse] {
        userGoals.filter { $0.status.lowercased() == "active" }
    }
    
    var completedGoals: [GoalResponse] {
        userGoals.filter { $0.status.lowercased() == "completed" }
    }
    
    func goals(byStatus status: GoalStatus?) -> [GoalResponse] {
        guard let status = status else {
            return userGoals
        }
        return userGoals.filter { $0.status.lowercased() == status.rawValue }
    }
    
    // MARK: - Catalog
    
    func loadCatalog() async {
        isCatalogLoading = true
        catalogError = nil
        defer { isCatalogLoading = false }
        
        do {
            catalog = try await service.getCatalog()
        } catch {
            catalogError = formatError(error)
            print("Error loading catalog: \(error)")
        }
    }
    
    func loadRecommendedGoals() async {
        do {
            recommendedGoals = try await service.getRecommendedGoals()
        } catch {
            print("Error loading recommended goals: \(error)")
            recommendedGoals = []
        }
    }
    
    // MARK: - Goals
    
    func loadGoals() async {
        isGoalsLoading = true
        goalsError = nil
        defer { isGoalsLoading = false }
        
        do {
            userGoals = try await service.getGoals()
        } catch {
            goalsError = formatError(error)
            print("Error loading goals: \(error)")
        }
    }
    
    func hasGoals() async -> Bool {
        do {
            let goals = try await service.getGoals()
            return !goals.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Progress
    
    func loadProgress() async {
        isProgressLoading = true
        progressError = nil
        defer { isProgressLoading = false }
        
        do {
            let response = try await service.getProgress()
            progress = response.goals
        } catch {
            progressError = formatError(error)
            print("Error loading progress: \(error)")
        }
    }
    
    // MARK: - Life Context
    
    func loadLifeContext() async {
        isContextLoading = true
        contextError = nil
        defer { isContextLoading = false }
        
        do {
            lifeContext = try await service.getLifeContext()
        } catch {
            contextError = formatError(error)
            print("Error loading life context: \(error)")
        }
    }
    
    func updateLifeContext(_ context: LifeContext) async {
        do {
            try await service.updateLifeContext(context)
            lifeContext = context
        } catch {
            contextError = formatError(error)
            print("Error updating life context: \(error)")
        }
    }
    
    // MARK: - Stepper
    
    func nextStep() {
        guard currentStep < 4 else { return }
        currentStep += 1
    }
    
    func previousStep() {
        guard currentStep > 1 else { return }
        currentStep -= 1
    }
    
    func addSelectedGoal(_ goal: GoalCatalogItem) {
        let selectedGoal = SelectedGoal(
            goalCategory: goal.goalCategory,
            goalName: goal.goalName
        )
        selectedGoals.append(selectedGoal)
    }
    
    func removeSelectedGoal(at index: Int) {
        guard index < selectedGoals.count else { return }
        selectedGoals.remove(at: index)
    }
    
    func updateSelectedGoal(at index: Int, with goal: SelectedGoal) {
        guard index < selectedGoals.count else { return }
        selectedGoals[index] = goal
    }
    
    func nextGoal() {
        guard currentGoalIndex < selectedGoals.count - 1 else { return }
        currentGoalIndex += 1
    }
    
    func previousGoal() {
        guard currentGoalIndex > 0 else { return }
        currentGoalIndex -= 1
    }
    
    func submitGoals(context: LifeContext) async -> Bool {
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        
        do {
            _ = try await service.submitGoals(context: context, selectedGoals: selectedGoals)
            
            // Reset stepper state
            currentStep = 1
            selectedGoals = []
            currentGoalIndex = 0
            
            // Reload goals and progress
            await loadGoals()
            await loadProgress()
            
            return true
        } catch {
            submitError = formatError(error)
            print("Error submitting goals: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatError(_ error: Error) -> String {
        if let goalsError = error as? GoalsError {
            return goalsError.errorDescription ?? "Unknown error"
        }
        return error.localizedDescription
    }
    
    func groupedCatalog() -> [String: [GoalCatalogItem]] {
        var grouped: [String: [GoalCatalogItem]] = [:]
        
        for item in catalog {
            let horizon = item.defaultHorizon
            if grouped[horizon] == nil {
                grouped[horizon] = []
            }
            grouped[horizon]?.append(item)
        }
        
        return grouped
    }
    
    // MARK: - AI Insights
    
    func loadAIInsights() async {
        isAIInsightsLoading = true
        aiInsightsError = nil
        defer { isAIInsightsLoading = false }
        
        // Mock AI insights for now - will be replaced with API call later
        await generateMockAIInsights()
    }
    
    private func generateMockAIInsights() async {
        var insights: [AIInsight] = []
        
        // Achievement insight
        if completedGoalsCount > 0 {
            insights.append(AIInsight(
                id: UUID(),
                title: "Goal Achievement Rate",
                message: "You're on track to complete \(Int((Double(completedGoalsCount) / Double(userGoals.count)) * 100))% of your goals this year!",
                type: .goalProgress,
                priority: .high,
                createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
                category: nil
            ))
        }
        
        // Optimization insight
        if let activeGoal = activeGoals.first, let goalProgress = progress.first(where: { $0.goalId == activeGoal.goalId.uuidString }) {
            let remaining = goalProgress.remainingAmount
            if remaining > 50000 {
                insights.append(AIInsight(
                    id: UUID(),
                    title: "Savings Optimization",
                    message: "Consider increasing your \(activeGoal.goalName.lowercased()) contribution by ₹5,000/month to reach your goal faster.",
                    type: .savingsOpportunity,
                    priority: .medium,
                    createdAt: Date().addingTimeInterval(-86400), // 1 day ago
                    category: activeGoal.goalName
                ))
            }
        }
        
        // Milestone insight
        if let milestoneGoal = progress.first(where: { $0.progressPct >= 70 && $0.progressPct < 100 }) {
            insights.append(AIInsight(
                id: UUID(),
                title: "Goal Milestone",
                message: "Congratulations! You've reached \(String(format: "%.0f", milestoneGoal.progressPct))% of your \(milestoneGoal.goalName.lowercased()) goal.",
                type: .goalProgress,
                priority: .low,
                createdAt: Date().addingTimeInterval(-259200), // 3 days ago
                category: milestoneGoal.goalName
            ))
        }
        
        // Default tip if no insights
        if insights.isEmpty {
            insights.append(AIInsight(
                id: UUID(),
                title: "Getting Started",
                message: "Set up your first goal to start tracking your financial progress!",
                type: .budgetTip,
                priority: .low,
                createdAt: Date(),
                category: nil
            ))
        }
        
        aiInsights = insights.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
}

