//
//  GoalSelectionStepView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalSelectionStepView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    @State private var selectedGoalKeys: Set<String> = []
    @State private var filter: GoalHorizon? = nil
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Your Goals")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Choose one or more financial goals to track.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Recommended Goals Section
                if !viewModel.recommendedGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recommended for You")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Select All") {
                                selectRecommended()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(goldColor)
                        }
                        
                        ForEach(viewModel.recommendedGoals) { goal in
                            GoalCatalogCard(
                                goal: goal,
                                isSelected: selectedGoalKeys.contains(key(for: goal)),
                                onToggle: {
                                    toggleGoal(goal)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: filter == nil,
                            action: { filter = nil }
                        )
                        
                        FilterChip(
                            title: "Short Term",
                            isSelected: filter == .shortTerm,
                            action: { filter = .shortTerm }
                        )
                        
                        FilterChip(
                            title: "Medium Term",
                            isSelected: filter == .mediumTerm,
                            action: { filter = .mediumTerm }
                        )
                        
                        FilterChip(
                            title: "Long Term",
                            isSelected: filter == .longTerm,
                            action: { filter = .longTerm }
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Catalog
                VStack(alignment: .leading, spacing: 16) {
                    Text("All Goals")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    ForEach(filteredGoals) { goal in
                        GoalCatalogCard(
                            goal: goal,
                            isSelected: selectedGoalKeys.contains(key(for: goal)),
                            onToggle: {
                                toggleGoal(goal)
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                }
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        saveSelectedGoals()
                        viewModel.nextStep()
                    }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(selectedGoalKeys.isEmpty ? goldColor.opacity(0.5) : goldColor)
                        .cornerRadius(12)
                    }
                    .disabled(selectedGoalKeys.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            loadSelectedGoals()
        }
    }
    
    private var filteredGoals: [GoalCatalogItem] {
        let goals = viewModel.catalog.filter { goal in
            !viewModel.recommendedGoals.contains { $0.goalName == goal.goalName && $0.goalCategory == goal.goalCategory }
        }
        
        if let filter = filter {
            return goals.filter { $0.defaultHorizon == filter.rawValue }
        }
        return goals
    }
    
    private func key(for goal: GoalCatalogItem) -> String {
        "\(goal.goalCategory):\(goal.goalName)"
    }
    
    private func toggleGoal(_ goal: GoalCatalogItem) {
        let key = key(for: goal)
        if selectedGoalKeys.contains(key) {
            selectedGoalKeys.remove(key)
            // Remove from selectedGoals
            viewModel.selectedGoals.removeAll { $0.goalCategory == goal.goalCategory && $0.goalName == goal.goalName }
        } else {
            selectedGoalKeys.insert(key)
            // Add to selectedGoals
            viewModel.addSelectedGoal(goal)
        }
    }
    
    private func selectRecommended() {
        for goal in viewModel.recommendedGoals {
            let key = key(for: goal)
            if !selectedGoalKeys.contains(key) {
                selectedGoalKeys.insert(key)
                viewModel.addSelectedGoal(goal)
            }
        }
    }
    
    private func loadSelectedGoals() {
        selectedGoalKeys = Set(viewModel.selectedGoals.map { "\($0.goalCategory):\($0.goalName)" })
    }
    
    private func saveSelectedGoals() {
        // Goals are already saved in viewModel.selectedGoals via toggleGoal
    }
}

// MARK: - Goal Catalog Card

struct GoalCatalogCard: View {
    let goal: GoalCatalogItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(isSelected ? goldColor : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? goldColor : Color.gray.opacity(0.5), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                
                // Goal Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.goalName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(goal.goalCategory)
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(horizonDisplayName(goal.defaultHorizon))
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.gray.opacity(isSelected ? 0.2 : 0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? goldColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func horizonDisplayName(_ horizon: String) -> String {
        switch horizon {
        case "short_term":
            return "Short Term"
        case "medium_term":
            return "Medium Term"
        case "long_term":
            return "Long Term"
        default:
            return horizon
        }
    }
}


#Preview {
    GoalSelectionStepView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

