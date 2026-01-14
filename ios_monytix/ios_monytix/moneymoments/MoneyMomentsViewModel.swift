//
//  MoneyMomentsViewModel.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MoneyMomentsViewModel: ObservableObject {
    private let service: MoneyMomentsService
    
    // Moments
    @Published var moments: [MoneyMoment] = []
    @Published var isMomentsLoading = false
    @Published var momentsError: String?
    
    // Nudges
    @Published var nudges: [Nudge] = []
    @Published var isNudgesLoading = false
    @Published var nudgesError: String?
    
    // Actions
    @Published var isComputing = false
    @Published var isEvaluating = false
    @Published var isProcessing = false
    @Published var actionError: String?
    
    // Success messages
    @Published var successMessage: String?
    
    init(authService: AuthService) {
        self.service = MoneyMomentsService(authService: authService)
    }
    
    // MARK: - Load Data
    
    func loadMoments(month: String? = nil) async {
        isMomentsLoading = true
        momentsError = nil
        defer { isMomentsLoading = false }
        
        do {
            if let month = month {
                // Load specific month
                print("[MoneyMoments] Loading moments for month: \(month)")
                moments = try await service.getMoments(month: month)
                print("[MoneyMoments] Successfully loaded \(moments.count) moments for month \(month)")
            } else {
                // Load data for the past 12 months
                print("[MoneyMoments] Loading moments for past year (allMonths=true)")
                moments = try await loadMomentsForPastYear()
                print("[MoneyMoments] Successfully loaded \(moments.count) total moments across past year")
            }
            
            // Log moment details for debugging
            if !moments.isEmpty {
                let uniqueHabitIds = Set(moments.map { $0.habitId })
                print("[MoneyMoments] Found \(uniqueHabitIds.count) unique habit IDs: \(Array(uniqueHabitIds).prefix(5).joined(separator: ", "))")
                let months = Set(moments.map { $0.month }).sorted()
                print("[MoneyMoments] Moments span \(months.count) months: \(months.prefix(3).joined(separator: ", "))")
            }
        } catch {
            momentsError = formatError(error)
            print("[MoneyMoments] ERROR loading moments: \(error)")
            if let urlError = error as? URLError {
                print("[MoneyMoments] URL Error details: \(urlError.localizedDescription)")
            }
        }
    }
    
    private func loadMomentsForPastYear() async throws -> [MoneyMoment] {
        // Request all months at once
        print("[MoneyMoments] Loading all moments for past year (allMonths=true)...")
        let allMoments = try await service.getMoments(month: nil, allMonths: true)
        print("[MoneyMoments] Loaded \(allMoments.count) total moments from backend")
        
        // Filter to past 12 months
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        guard let cutoffDate = calendar.date(byAdding: .month, value: -12, to: now) else {
            print("Warning: Could not calculate cutoff date, returning all moments")
            return allMoments
        }
        
        let cutoffMonth = formatter.string(from: cutoffDate)
        
        let filteredMoments = allMoments.filter { moment in
            moment.month >= cutoffMonth
        }
        
        print("Filtered to \(filteredMoments.count) moments from past 12 months (cutoff: \(cutoffMonth))")
        return filteredMoments
    }
    
    func loadNudges(limit: Int = 200) async {
        isNudgesLoading = true
        nudgesError = nil
        defer { isNudgesLoading = false }
        
        do {
            print("[MoneyMoments] Loading nudges with limit: \(limit)")
            nudges = try await service.getNudges(limit: limit)
            print("[MoneyMoments] Successfully loaded \(nudges.count) nudges")
            
            if !nudges.isEmpty {
                let statuses = Dictionary(grouping: nudges) { $0.sendStatus }
                print("[MoneyMoments] Nudge status breakdown: \(statuses.mapValues { $0.count })")
            }
        } catch {
            nudgesError = formatError(error)
            print("[MoneyMoments] ERROR loading nudges: \(error)")
            if let urlError = error as? URLError {
                print("[MoneyMoments] URL Error details: \(urlError.localizedDescription)")
            }
        }
    }
    
    func loadAll() async {
        print("[MoneyMoments] Loading all data (moments and nudges)...")
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMoments() }
            group.addTask { await self.loadNudges(limit: 200) }
        }
        print("[MoneyMoments] Finished loading all data. Moments: \(moments.count), Nudges: \(nudges.count), Habits: \(habits.count)")
    }
    
    // MARK: - Actions
    
    func computeMoments(targetMonth: String? = nil) async -> Bool {
        isComputing = true
        actionError = nil
        successMessage = nil
        defer { 
            isComputing = false
            print("[MoneyMoments] computeMoments completed, isComputing set to false")
        }
        
        do {
            print("[MoneyMoments] ===== STARTING computeMoments =====")
            print("[MoneyMoments] Computing moments for targetMonth: \(targetMonth ?? "current month")")
            print("[MoneyMoments] About to call service.computeMoments...")
            
            let response = try await service.computeMoments(targetMonth: targetMonth)
            
            print("[MoneyMoments] ===== COMPUTE RESPONSE RECEIVED =====")
            print("[MoneyMoments] Compute response: status=\(response.status), count=\(response.count), message=\(response.message ?? "none")")
            print("[MoneyMoments] Response moments count: \(response.moments.count)")
            
            moments = response.moments
            successMessage = response.message ?? "Computed \(response.count) money moments!"
            
            print("[MoneyMoments] Moments assigned to viewModel.moments, count: \(moments.count)")
            
            // Reload moments to get updated data
            print("[MoneyMoments] Reloading moments from backend...")
            await loadMoments()
            print("[MoneyMoments] Moments reloaded, final count: \(moments.count)")
            
            return true
        } catch {
            actionError = formatError(error)
            print("[MoneyMoments] ===== ERROR IN computeMoments =====")
            print("[MoneyMoments] ERROR computing moments: \(error)")
            print("[MoneyMoments] Error type: \(type(of: error))")
            if let urlError = error as? URLError {
                print("[MoneyMoments] URL Error code: \(urlError.code.rawValue)")
                print("[MoneyMoments] URL Error details: \(urlError.localizedDescription)")
                print("[MoneyMoments] URL Error userInfo: \(urlError.userInfo)")
            }
            if let moneyMomentsError = error as? MoneyMomentsError {
                print("[MoneyMoments] MoneyMomentsError: \(moneyMomentsError.localizedDescription)")
            }
            return false
        }
    }
    
    func computeMomentsForPastYear() async -> Bool {
        print("[MoneyMoments] ========================================")
        print("[MoneyMoments] ===== computeMomentsForPastYear CALLED =====")
        print("[MoneyMoments] ========================================")
        
        isComputing = true
        actionError = nil
        successMessage = nil
        defer { 
            isComputing = false
            print("[MoneyMoments] computeMomentsForPastYear completed, isComputing set to false")
        }
        
        // Generate list of months for the past 12 months
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        var monthStrings: [String] = []
        for i in 0..<12 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else {
                continue
            }
            monthStrings.append(formatter.string(from: monthDate))
        }
        
        print("[MoneyMoments] Computing moments for \(monthStrings.count) months: \(monthStrings.joined(separator: ", "))")
        
        var totalComputed = 0
        var errors: [String] = []
        
        // Compute moments for all months in parallel
        await withTaskGroup(of: (String, Bool, Int).self) { group in
            for monthString in monthStrings {
                group.addTask {
                    do {
                        print("[MoneyMoments] Computing moments for month: \(monthString)")
                        let response = try await self.service.computeMoments(targetMonth: monthString)
                        print("[MoneyMoments] Successfully computed \(response.count) moments for month \(monthString) (status: \(response.status))")
                        return (monthString, true, response.count)
                    } catch {
                        print("[MoneyMoments] ERROR computing moments for month \(monthString): \(error)")
                        return (monthString, false, 0)
                    }
                }
            }
            
            for await (month, success, count) in group {
                if success {
                    totalComputed += count
                } else {
                    errors.append(month)
                }
            }
        }
        
        print("[MoneyMoments] Compute summary: \(totalComputed) moments computed, \(errors.count) months failed")
        if !errors.isEmpty {
            print("[MoneyMoments] Failed months: \(errors.joined(separator: ", "))")
        }
        
        if totalComputed > 0 {
            successMessage = "Computed \(totalComputed) moments across \(monthStrings.count) months!"
            // Reload moments to get updated data
            await loadMoments()
            return true
        } else {
            actionError = "No moments could be computed. Please ensure you have transaction data uploaded."
            return false
        }
    }
    
    func evaluateAndDeliverNudges() async -> Bool {
        isEvaluating = true
        actionError = nil
        successMessage = nil
        defer { isEvaluating = false }
        
        do {
            print("[MoneyMoments] Starting nudge evaluation and delivery process")
            
            // Optionally compute signal first (non-critical if it fails)
            do {
                print("[MoneyMoments] Computing signal for nudge evaluation...")
                _ = try await service.computeSignal()
                print("[MoneyMoments] Signal computed successfully")
            } catch {
                print("[MoneyMoments] WARNING: Signal computation failed (may not be critical): \(error)")
            }
            
            // Evaluate nudges
            print("[MoneyMoments] Evaluating nudge rules...")
            let evalResponse = try await service.evaluateNudges()
            print("[MoneyMoments] Evaluation complete: status=\(evalResponse.status), count=\(evalResponse.count)")
            if let candidates = evalResponse.candidates {
                print("[MoneyMoments] Candidate IDs: \(candidates.prefix(5).joined(separator: ", "))")
            }
            successMessage = "Evaluated \(evalResponse.count) nudge candidates"
            
            // Process and deliver nudges
            isProcessing = true
            defer { isProcessing = false }
            
            print("[MoneyMoments] Processing and delivering nudges (limit: 10)...")
            let processResponse = try await service.processNudges(limit: 10)
            print("[MoneyMoments] Processing complete: delivered \(processResponse.count) nudges")
            successMessage = "Processed and delivered \(processResponse.count) nudges!"
            
            // Reload nudges
            await loadNudges()
            
            return true
        } catch {
            actionError = formatError(error)
            print("[MoneyMoments] ERROR evaluating/processing nudges: \(error)")
            if let urlError = error as? URLError {
                print("[MoneyMoments] URL Error details: \(urlError.localizedDescription)")
            }
            return false
        }
    }
    
    func logNudgeInteraction(
        deliveryId: String,
        eventType: String,
        metadata: [String: Any]? = nil
    ) async {
        do {
            _ = try await service.logNudgeInteraction(
                deliveryId: deliveryId,
                eventType: eventType,
                metadata: metadata
            )
        } catch {
            print("Error logging nudge interaction: \(error)")
            // Don't show error to user for interaction tracking
        }
    }
    
    // MARK: - Computed Properties (Data Transformation)
    
    var habits: [Habit] {
        // Group moments by habit_id and transform into habits
        guard !moments.isEmpty else {
            print("[MoneyMoments] No moments available to transform into habits")
            return []
        }
        
        print("[MoneyMoments] Transforming \(moments.count) moments into habits")
        let grouped = Dictionary(grouping: moments) { $0.habitId }
        print("[MoneyMoments] Found \(grouped.count) unique habit IDs")
        
        if grouped.count <= 10 {
            print("[MoneyMoments] Habit IDs: \(grouped.keys.joined(separator: ", "))")
        } else {
            print("[MoneyMoments] First 10 habit IDs: \(Array(grouped.keys.prefix(10)).joined(separator: ", "))")
        }
        
        return grouped.map { (habitId, moments) in
            let latestMoment = moments.max(by: { $0.createdAt < $1.createdAt }) ?? moments.first!
            
            // Determine priority from confidence
            let priority: HabitPriority
            if latestMoment.confidence >= 0.7 {
                priority = .high
            } else if latestMoment.confidence >= 0.5 {
                priority = .medium
            } else {
                priority = .low
            }
            
            // Determine frequency from habit_id pattern
            let frequency: HabitFrequency
            if habitId.contains("daily") || habitId.contains("7d") {
                frequency = .daily
            } else if habitId.contains("weekly") || habitId.contains("30d") {
                frequency = .weekly
            } else {
                frequency = .monthly
            }
            
            // Calculate streak from consecutive months
            let sortedMonths = moments.map { $0.month }.sorted()
            let currentStreak = calculateStreak(months: sortedMonths)
            let targetStreak = 30 // Default target
            
            // Determine icon based on habit_id
            let icon = getIconForHabit(habitId: habitId)
            
            // Parse created_at date with multiple fallback strategies
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var createdAt: Date? = dateFormatter.date(from: latestMoment.createdAt)
            
            if createdAt == nil {
                // Try without fractional seconds
                let formatter2 = ISO8601DateFormatter()
                formatter2.formatOptions = [.withInternetDateTime]
                createdAt = formatter2.date(from: latestMoment.createdAt)
            }
            
            if createdAt == nil {
                // Try with basic date format
                let formatter3 = DateFormatter()
                formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter3.timeZone = TimeZone(secondsFromGMT: 0)
                createdAt = formatter3.date(from: latestMoment.createdAt)
            }
            
            if createdAt == nil {
                // Try with date only format
                let formatter4 = DateFormatter()
                formatter4.dateFormat = "yyyy-MM-dd"
                formatter4.timeZone = TimeZone(secondsFromGMT: 0)
                createdAt = formatter4.date(from: latestMoment.createdAt)
            }
            
            // Use current date as last resort
            let finalCreatedAt = createdAt ?? Date()
            
            if createdAt == nil {
                print("Warning: Failed to parse date '\(latestMoment.createdAt)' for habit \(habitId), using current date")
            }
            
            return Habit(
                id: habitId,
                habitId: habitId,
                name: latestMoment.label,
                description: latestMoment.insightText,
                priority: priority,
                frequency: frequency,
                currentStreak: currentStreak,
                targetStreak: targetStreak,
                icon: icon,
                createdAt: finalCreatedAt
            )
        }.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var progressMetrics: ProgressMetrics {
        // Calculate streak from moments/nudges activity
        let streak = calculateActivityStreak()
        
        // Count nudges
        let nudgesCount = nudges.count
        
        // Count unique habits
        let habitsCount = Set(moments.map { $0.habitId }).count
        
        // Calculate saved amount from savings-related moments
        let savedAmount = moments
            .filter { $0.habitId.contains("savings") || $0.habitId.contains("assets") || $0.habitId.contains("surplus") }
            .reduce(0.0) { $0 + $1.value }
        
        print("[MoneyMoments] Progress Metrics - Streak: \(streak), Nudges: \(nudgesCount), Habits: \(habitsCount), Saved: ₹\(savedAmount)")
        
        return ProgressMetrics(
            streak: streak,
            nudgesCount: nudgesCount,
            habitsCount: habitsCount,
            savedAmount: savedAmount
        )
    }
    
    var aiInsights: [MoneyMomentsAIInsight] {
        var insights: [MoneyMomentsAIInsight] = []
        
        // Transform high-confidence moments into progress insights
        let highConfidenceMoments = moments.filter { $0.confidence >= 0.7 }
        for moment in highConfidenceMoments.prefix(3) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = dateFormatter.date(from: moment.createdAt) ?? 
                           ISO8601DateFormatter().date(from: moment.createdAt) ?? Date()
            
            insights.append(MoneyMomentsAIInsight(
                id: "moment_\(moment.id)",
                type: .progress,
                message: "You've maintained a \(Int(moment.confidence * 100))% confidence in \(moment.label). Keep up the momentum!",
                timestamp: timestamp,
                icon: MoneyMomentsInsightType.progress.icon
            ))
        }
        
        // Transform actionable moments into suggestions
        let actionableMoments = moments.filter { 
            $0.insightText.lowercased().contains("consider") || 
            $0.insightText.lowercased().contains("suggest")
        }
        for moment in actionableMoments.prefix(2) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = dateFormatter.date(from: moment.createdAt) ?? 
                           ISO8601DateFormatter().date(from: moment.createdAt) ?? Date()
            
            insights.append(MoneyMomentsAIInsight(
                id: "suggestion_\(moment.id)",
                type: .suggestion,
                message: moment.insightText,
                timestamp: timestamp,
                icon: MoneyMomentsInsightType.suggestion.icon
            ))
        }
        
        // Transform savings moments into milestones
        let savingsMoments = moments.filter { 
            $0.habitId.contains("savings") || $0.habitId.contains("assets")
        }
        for moment in savingsMoments.prefix(2) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = dateFormatter.date(from: moment.createdAt) ?? 
                           ISO8601DateFormatter().date(from: moment.createdAt) ?? Date()
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "INR"
            formatter.currencySymbol = "₹"
            formatter.maximumFractionDigits = 0
            let savedText = formatter.string(from: NSNumber(value: moment.value)) ?? "₹\(Int(moment.value))"
            
            insights.append(MoneyMomentsAIInsight(
                id: "milestone_\(moment.id)",
                type: .milestone,
                message: "You've saved \(savedText) through your smart habits this month!",
                timestamp: timestamp,
                icon: MoneyMomentsInsightType.milestone.icon
            ))
        }
        
        // Add nudges as insights
        for nudge in nudges.prefix(5) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = dateFormatter.date(from: nudge.sentAt) ?? 
                           ISO8601DateFormatter().date(from: nudge.sentAt) ?? Date()
            
            insights.append(MoneyMomentsAIInsight(
                id: "nudge_\(nudge.id)",
                type: .suggestion,
                message: nudge.body ?? nudge.bodyTemplate ?? nudge.title ?? "",
                timestamp: timestamp,
                icon: MoneyMomentsInsightType.suggestion.icon
            ))
        }
        
        // Sort by timestamp (most recent first)
        return insights.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Helper Methods
    
    private func formatError(_ error: Error) -> String {
        if let moneyMomentsError = error as? MoneyMomentsError {
            return moneyMomentsError.localizedDescription
        }
        return error.localizedDescription
    }
    
    private func calculateStreak(months: [String]) -> Int {
        guard !months.isEmpty else { return 0 }
        
        // Sort months and find consecutive sequence
        let sorted = months.sorted()
        var streak = 1
        var maxStreak = 1
        
        for i in 1..<sorted.count {
            if areConsecutiveMonths(sorted[i-1], sorted[i]) {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 1
            }
        }
        
        return maxStreak
    }
    
    private func areConsecutiveMonths(_ month1: String, _ month2: String) -> Bool {
        // Format: "YYYY-MM"
        let components1 = month1.split(separator: "-")
        let components2 = month2.split(separator: "-")
        
        guard components1.count == 2, components2.count == 2,
              let year1 = Int(components1[0]), let month1 = Int(components1[1]),
              let year2 = Int(components2[0]), let month2 = Int(components2[1]) else {
            return false
        }
        
        // Check if month2 is one month after month1
        if year2 == year1 && month2 == month1 + 1 {
            return true
        }
        if year2 == year1 + 1 && month1 == 12 && month2 == 1 {
            return true
        }
        
        return false
    }
    
    private func calculateActivityStreak() -> Int {
        // Calculate streak from moments and nudges activity
        var activityDates: Set<String> = []
        
        // Add dates from moments
        for moment in moments {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: moment.createdAt) ?? 
                          ISO8601DateFormatter().date(from: moment.createdAt) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"
                activityDates.insert(dayFormatter.string(from: date))
            }
        }
        
        // Add dates from nudges
        for nudge in nudges {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: nudge.sentAt) ?? 
                          ISO8601DateFormatter().date(from: nudge.sentAt) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"
                activityDates.insert(dayFormatter.string(from: date))
            }
        }
        
        // Calculate consecutive days
        let sortedDates = activityDates.sorted()
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 1
        var maxStreak = 1
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for i in 1..<sortedDates.count {
            if let date1 = dateFormatter.date(from: sortedDates[i-1]),
               let date2 = dateFormatter.date(from: sortedDates[i]),
               Calendar.current.dateComponents([.day], from: date1, to: date2).day == 1 {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 1
            }
        }
        
        return maxStreak
    }
    
    private func getIconForHabit(habitId: String) -> String {
        if habitId.contains("morning") || habitId.contains("daily") {
            return "sun.max.fill"
        } else if habitId.contains("spend") || habitId.contains("no_spend") {
            return "xmark.circle.fill"
        } else if habitId.contains("savings") || habitId.contains("transfer") {
            return "building.columns.fill"
        } else if habitId.contains("dining") {
            return "fork.knife"
        } else if habitId.contains("shopping") {
            return "bag.fill"
        } else {
            return "chart.bar.fill"
        }
    }
}

